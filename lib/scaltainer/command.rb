require "logger"
require "optparse"

module Scaltainer
  class Command
    def self.parse(args)
      configfile, statefile, wait, orchestrator = 'scaltainer.yml', nil, 0, :swarm
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
          puts "General options:"
          puts "- HIREFIRE_TOKEN"
          puts "- NEW_RELIC_API_KEY"
          puts "- RESPONSE_TIME_WINDOW: defaults to 5"
          puts "- LOG_LEVEL: defaults to INFO"
          puts "- DOCKER_SECRETS_PATH_GLOB: path glob containing env files to load"
          exit
        end     
      end.parse!

      statefile = "#{configfile}.state" unless statefile

      raise ConfigurationError.new("File not found: #{configfile}") unless File.exists?(configfile)

      load_env

      logger = Logger.new(STDOUT)
      logger.level = %w(debug info warn error fatal unknown).find_index((ENV['LOG_LEVEL'] || '').downcase) || 1

      return configfile, statefile, logger, wait, orchestrator
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
