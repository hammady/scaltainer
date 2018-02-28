require 'kubeclient'

module Scaltainer
  class KubeResource < ReplicaSetBase
    def initialize(name, type, namespace)
      @@client ||= self.class.get_client
      # if namespace not specified, use the one found in configuration
      namespace ||= @@namespace || 'default'
      super(name, type, namespace)
      @resource = @@client.send("get_#{@type}", @name, @namespace)
      @id = @resource.metadata.uid
    end

    def get_replicas
      @resource.spec.replicas
    end

    def set_replicas(replicas)
      @@client.send("patch_#{@type}", @name, {spec: {replicas: replicas}}, @namespace)
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
      auth_options = {bearer_token: read_secret(serviceaccount, 'token')}
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
      File.read("#{serviceaccount}/#{secret}")
    end
  end
end
