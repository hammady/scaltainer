require "logger"
require "optparse"

module Scaltainer
  class Command
    def self.parse(args)
      configfile, statefile = 'scaltainer.yml', nil
      OptionParser.new do |opts|
        opts.banner = "Usage: scaltainer [options]"
        opts.on("-f", "--conf-file FILE", "Specify configuration file (default: scaltainer.yml)") do |file|
          configfile = file
        end
        opts.on("--state-file FILE", "Specify state file (default: <conf-file>.state)") do |file|
          statefile = file
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          puts "\nEnvironment variables: \n"
          puts "- DOCKER_URL: defaults to local socket"
          puts "- HIREFIRE_TOKEN"
          puts "- NEW_RELIC_LICENSE_KEY"
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

      return configfile, statefile, logger
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
          puts ENV['NEW_RELIC_LICENSE_KEY']
        end
      end
    end
  end
end
