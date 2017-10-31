require "logger"
require "optparse"

module Scaltainer
  class Command
    def self.parse(args)
      configfile = 'scaltainer.yml'
      OptionParser.new do |opts|
        opts.banner = "Usage: scaltainer [options]"
        opts.on("-f", "--file FILE", "Specify configuration file (default: scaltainer.yml)") do |file|
          configfile = file
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end     
      end.parse!

      raise ConfigurationError.new("File not found: #{configfile}") unless File.exists?(configfile)
      logger = Logger.new(STDOUT)
      logger.level = %w(debug info warn error fatal unknown).find_index((ENV['LOG_LEVEL'] || '').downcase) || 1

      return configfile, logger
    end
  end
end
