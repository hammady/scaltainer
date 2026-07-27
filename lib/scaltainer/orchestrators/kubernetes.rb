require 'kubeclient'

module Scaltainer
  class KubeResource < ReplicaSetBase
    def initialize(name, namespace)
      @@client ||= self.class.get_client
      type = ENV['KUBERNETES_CONTROLLER_KIND'] || 'deployment'
      # if namespace not specified, use the one found in configuration
      namespace ||= @@namespace || 'default'
      super(name, type, namespace)
      @resource = self.class.raising_authentication_errors do
        @@client.send("get_#{@type}", normalize_name(@name), @namespace)
      end
      @id = @resource.metadata.uid
    end

    def get_replicas
      @resource.spec.replicas
    end

    def set_replicas(replicas)
      self.class.raising_authentication_errors do
        @@client.send("patch_#{@type}", normalize_name(@name), {spec: {replicas: replicas}}, @namespace)
      end
    end

    # Translate an HTTP 401 from the Kubernetes API into Scaltainer::AuthenticationError.
    #
    # 401 (as opposed to 403) means the API server could not authenticate us at
    # all, before RBAC was even consulted. For a pod authenticating with a
    # projected service account token that almost always means the bearer token
    # this process read at startup has expired: kubelet rotates the file on disk
    # (at 80% of the token TTL, or every 24h, whichever comes first) but the
    # token is passed to Kubeclient as a string, so a long-running process keeps
    # presenting the copy it read when it booted.
    #
    # Retrying cannot fix that, and neither can skipping the service, so we let
    # the error escape all the way out of the run loop and terminate the
    # process. Kubernetes then restarts the container, which re-reads the token.
    #
    # 403 and every other status are left alone: those are genuine
    # authorization/config problems where crash-looping would only hide the
    # cause and stop the remaining services from being scaled.
    def self.raising_authentication_errors
      yield
    rescue Kubeclient::HttpError => e
      raise unless e.error_code == 401
      raise Scaltainer::AuthenticationError.new(
        "Kubernetes API returned 401 Unauthorized: #{e.message}. " \
        "The credential this process is using is no longer accepted " \
        "(most likely an expired service account token that was read once at " \
        "startup). Exiting so the container is restarted with a fresh token."
      )
    end

    private

    def self.get_client
      if ENV['KUBECONFIG']
        get_client_from_kubeconfig ENV['KUBECONFIG']
      else
        get_client_from_serviceaccount '/var/run/secrets/kubernetes.io/serviceaccount'
      end
    end

    def self.get_client_from_kubeconfig(kubeconfig)
      config = Kubeclient::Config.read(kubeconfig)
      url = get_api_url(config.context.api_endpoint)
      version = get_api_version(config.context.api_version)
      # @@namespace = config.context.namespace # wait till PR#308 merged into kubeclient
      Kubeclient::Client.new(
        url, version,
        ssl_options: config.context.ssl_options,
        auth_options: config.context.auth_options
      )
    end

    def self.get_client_from_serviceaccount(serviceaccount)
      ssl_verify = if ENV['KUBERNETES_SKIP_SSL_VERIFY']
        OpenSSL::SSL::VERIFY_NONE
      else
        OpenSSL::SSL::VERIFY_PEER
      end
      ssl_options = {
        client_cert: OpenSSL::X509::Certificate.new(read_secret(serviceaccount, 'ca.crt')),
        verify_ssl: ssl_verify
      }
      # Pass the *path*, not the contents. Kubeclient >= 4.10 re-reads this file
      # on every request, so a long-lived client keeps working when kubelet
      # rotates the projected service account token underneath us.
      #
      # Reading the token once here (`bearer_token: read_secret(...)`) froze it
      # at boot: since Kubernetes 1.21 in-cluster tokens are short-lived and
      # rotated in place, so every request started failing with 401 once the
      # boot-time copy expired, and only a restart cleared it.
      auth_options = {bearer_token_file: token_path(serviceaccount)}
      @@namespace = read_secret(serviceaccount, 'namespace')
      url = get_api_url('https://kubernetes.default:443')
      version = get_api_version('v1')
      Kubeclient::Client.new(
        url, version,
        ssl_options: ssl_options,
        auth_options: auth_options
      )
    end

    def self.get_api_url(default_server)
      server = ENV['KUBERNETES_API_SERVER'] || default_server
      endpoint = ENV['KUBERNETES_API_ENDPOINT'] || '/api'
      "#{server}#{endpoint}"
    end

    def self.get_api_version(default_version)
      ENV['KUBERNETES_API_VERSION'] || default_version
    end

    def self.read_secret(serviceaccount, secret)
      File.read(secret_path(serviceaccount, secret))
    end

    def self.secret_path(serviceaccount, secret)
      "#{serviceaccount}/#{secret}"
    end

    def self.token_path(serviceaccount)
      secret_path(serviceaccount, 'token')
    end

    def normalize_name(name)
      name.gsub(/_/, '-')
    end
  end
end
