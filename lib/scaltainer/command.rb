require "logger"
require "optparse"

module Scaltainer
  class Command
    def self.parse(args)
      configfile, statefile, wait, orchestrator, pushgateway, enable_newrelic_reporting = 'scaltainer.yml', nil, 0, :swarm, nil, false
      OptionParser.new do |opts|
        opts.banner = "Usage: scaltainer [options]"
        opts.on("-f", "--conf-file FILE", "Specify configuration file (default: scaltainer.yml)") do |file|
          configfile = file
        end
        opts.on("--state-file FILE", "Specify state file (default: <conf-file>.state)") do |file|
          statefile = file
        end
        opts.on("-w", "--wait SECONDS", "Specify wait time between repeated calls, 0 for no repetition (default: 0)") do |w|
          wait = w.to_i
        end
        opts.on("-o", "--orchestrator swarm:kubernetes", [:swarm, :kubernetes], "Specify orchestrator type (default: swarm)") do |o|
          orchestrator = o
        end
        opts.on("-g", "--prometheus-push-gateway ADDRESS", "Specify prometheus push gateway address in the form of host:port") do |gw|
          pushgateway = gw
        end
        opts.on("--enable-newrelic-reporting", "Enable metrics pushing to New Relic") do
          newrelic_license_key = ENV['NEW_RELIC_LICENSE_KEY']
          newrelic_app_name = ENV['NEW_RELIC_APP_NAME']
          raise 'Must set NEW_RELIC_LICENSE_KEY environment variable if --enable-newrelic-reporting is set' if newrelic_license_key.nil? || newrelic_license_key == ""
          raise 'Must set NEW_RELIC_APP_NAME environment variable if --enable-newrelic-reporting is set' if newrelic_app_name.nil? || newrelic_app_name == ""
          enable_newrelic_reporting = true
        end
        opts.on("-v", "--version", "Show version and exit") do
          puts Scaltainer::VERSION
          exit 0
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          puts "\nEnvironment variables: \n"
          puts "Docker Swarm options:"
          puts "- DOCKER_URL: defaults to local socket"
          puts "Kubernetes options:"
          puts "- KUBECONFIG: set to Kubernetes config (default: $HOME/.kube/config) if you want to connect to the current configured cluster"
          puts "- KUBERNETES_API_SERVER: overrides option in KUBECONFIG and defaults to https://kubernetes.default:443"
          puts "- KUBERNETES_SKIP_SSL_VERIFY: KUBECONFIG option overrides this, set to any value to skip SSL verification"
          puts "- KUBERNETES_API_ENDPOINT: defaults to /api"
          puts "- KUBERNETES_API_VERSION: overrides option in KUBECONFIG and defaults to v1"
          puts "- KUBERNETES_CONTROLLER_KIND: controller kind to scale, allowed values: deployment (default), replication_controller, or replica_set"
          puts "  Make sure the KUBERNETES_CONTROLLER_KIND you specify is part of the api specified using KUBERNETES_API_ENDPOINT and KUBERNETES_API_VERSION"
          puts "General options:"
          puts "- HIREFIRE_TOKEN"
          puts "- NEW_RELIC_API_KEY: New Relic API key for retrieving web metrics"
          puts "- RESPONSE_TIME_WINDOW: defaults to 5"
          puts "- LOG_LEVEL: defaults to INFO"
          puts "- DOCKER_SECRETS_PATH_GLOB: path glob containing env files to load"
          puts "- NEW_RELIC_LICENSE_KEY: New Relic license key, required if --enable_newrelic_reporting is used"
          puts "- NEW_RELIC_APP_NAME: New Relic application name, required if --enable_newrelic_reporting is used"
          exit
        end     
      end.parse!

      statefile = "#{configfile}.state" unless statefile

      raise ConfigurationError.new("File not found: #{configfile}") unless File.exists?(configfile)

      load_env

      logger = Logger.new(STDOUT)
      logger.level = %w(debug info warn error fatal unknown).find_index((ENV['LOG_LEVEL'] || '').downcase) || 1

      return configfile, statefile, logger, wait, orchestrator, pushgateway, enable_newrelic_reporting
    end

    private

    def self.load_env
      # load docker configs/secrets
      path = ENV['DOCKER_SECRETS_PATH_GLOB']
      unless path.nil?
        files = Dir[path]
        unless files.empty?
          require 'dotenv'
          Dotenv.load(*files)
        end
      end
    end
  end
end
