require "scaltainer/version"
require "scaltainer/exceptions"
require "scaltainer/service_type"
require "docker"
require "docker/service"
require "yaml"
require "logger"
require "optparse"

module Scaltainer
  class Command
    def initialize(args)
      @configfile = 'scaltainer.yml'
      OptionParser.new do |opts|
        opts.banner = "Usage: scaltainer [options]"
        opts.on("-f", "--file FILE", "Specify configuration file (default: scaltainer.yml)") do |file|
          @configfile = file
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end     
      end.parse!
      @statefile = "#{@configfile}.state"

      raise ConfigurationError.new("File not found: #{@configfile}") unless File.exists?(@configfile)
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      Docker.logger = logger
    end

    def run
      config = YAML.load_file @configfile
      state = get_state || {}
      endpoint = config["endpoint"]
      service_prefix = config["stack_name"]
      iterate_services config["web_services"], service_prefix, ServiceTypeWeb.new(endpoint), state
      iterate_services config["worker_services"], service_prefix, ServiceTypeWorker.new(endpoint), state
      save_state state
    end

    private

    def get_state
      YAML.load_file @statefile if File.exists? @statefile
    end

    def save_state(state)
      File.write(@statefile, state.to_yaml)
    end

    def get_service(service_name)
      service = Docker::Service.all(filters: {name: [service_name]}.to_json)[0]
      raise ConfigurationError.new("Unknown service to docker: #{service_name}") unless service
      service
    end

    def get_service_replicas(service)
      # ask docker about replicas for service
      replicated = service.info["Spec"]["Mode"]["Replicated"]
      raise ConfigurationError.new("Cannot replicate a global service: #{service.info['Spec']['Name']}") unless replicated
      replicated["Replicas"]
    end

    def iterate_services(services, service_prefix, type, state)
      begin
        metrics = type.get_metrics services
        services.each do |service_name, service_config|
          begin
            state[service_name] ||= {}
            service_state = state[service_name]
            process_service_logic(service_name, service_config, service_state, service_prefix, type, metrics)
          rescue RuntimeError => e
            # skipping service
            $stderr.puts e.message
          end
        end
      rescue RuntimeError => e
        # skipping service type
        $stderr.puts e.message
      end
    end

    def process_service_logic(service_name, config, state, prefix, type, metrics)
      # TODO merge default configs in config
      full_service_name = prefix ? "#{prefix}_#{service_name}" : service_name
      service = get_service full_service_name
      current_replicas = get_service_replicas service
      metric = metrics[service_name]
      raise Warning.new("Configured service '#{service_name}' not found in metrics endpoint") unless metric
      desired_replicas = type.determine_desired_replicas(metric, config, current_replicas)
      desired_replicas = [config["max"], desired_replicas].min
      desired_replicas = [config["min"], desired_replicas].max
      diff = desired_replicas - current_replicas
      if diff > 0
        # breach: change state and scale up
        state["upscale_sensitivity"] ||= 0
        state["upscale_sensitivity"] += 1
        state["downscale_sensitivity"] = 0
        if state["upscale_sensitivity"] >= config["upscale_sensitivity"]
          scale_out service, current_replicas, desired_replicas
          state["upscale_sensitivity"] = 0
        end
      elsif diff < 0
        # breach: change state and scale down
        if type.class == ServiceTypeWeb || metric == 0 || config["decrementable"]
          state["downscale_sensitivity"] ||= 0
          state["downscale_sensitivity"] += 1
          state["upscale_sensitivity"] = 0
          if state["downscale_sensitivity"] >= config["downscale_sensitivity"]
            scale_out service, current_replicas, desired_replicas
            state["downscale_sensitivity"] = 0
          end
        end
      else
        # no breach, change state
        state["upscale_sensitivity"] = 0
        state["downscale_sensitivity"] = 0
      end
    end

    def scale_out(service, current_replicas, desired_replicas)
      return if current_replicas == desired_replicas
      # send scale command to docker
      puts "Scaling #{service.info['Spec']['Name']} from #{current_replicas} to #{desired_replicas}"
      service.scale desired_replicas
    end

  end
end
