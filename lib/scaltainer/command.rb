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
          exit
        end     
      end.parse!

      statefile = "#{configfile}.state" unless statefile

      raise ConfigurationError.new("File not found: #{configfile}") unless File.exists?(configfile)
      logger = Logger.new(STDOUT)
      logger.level = %w(debug info warn error fatal unknown).find_index((ENV['LOG_LEVEL'] || '').downcase) || 1

      return configfile, statefile, logger
    end
  end
end
