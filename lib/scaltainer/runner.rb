require "yaml"

module Scaltainer
  class Runner
    def initialize(configfile, statefile, logger)
      @logger = logger
      @default_service_config = {
        "min" => 0,
        "upscale_quantity" => 1,
        "downscale_quantity" => 1,
        "upscale_sensitivity" => 1,
        "downscale_sensitivity" => 1
      }
      @logger.debug "Scaltainer initialized with configuration file: #{configfile}, and state file: #{statefile}"
      config = YAML.load_file configfile
      Docker.logger = @logger
      state = get_state(statefile) || {}
      endpoint = config["endpoint"]
      service_prefix = config["stack_name"]
      iterate_services config["web_services"], service_prefix, ServiceTypeWeb.new(endpoint), state
      iterate_services config["worker_services"], service_prefix, ServiceTypeWorker.new(endpoint), state
      save_state statefile, state
    end

    private

    def get_state(statefile)
      YAML.load_file statefile if File.exists? statefile
    end

    def save_state(statefile, state)
      File.write(statefile, state.to_yaml)
    end

    def get_service(service_name)
      begin
        service = Docker::Service.all(filters: {name: [service_name]}.to_json)[0]
      rescue => e
        raise NetworkError.new "Could not get service with name #{service_name} from docker engine at #{Docker.url}.\n#{e.message}"
      end
      raise ConfigurationError.new "Unknown service to docker: #{service_name}" unless service
      service
    end

    def get_service_replicas(service)
      # ask docker about replicas for service
      replicated = service.info["Spec"]["Mode"]["Replicated"]
      raise ConfigurationError.new "Cannot replicate a global service: #{service.info['Spec']['Name']}" unless replicated
      replicated["Replicas"]
    end

    def iterate_services(services, service_prefix, type, state)
      begin
        metrics = type.get_metrics services
        @logger.debug "Retrieved metrics for #{type} services: #{metrics}"
        services.each do |service_name, service_config|
          begin
            state[service_name] ||= {}
            service_state = state[service_name]
            @logger.debug "Service #{service_name} currently has state: #{service_state}"
            service_config = @default_service_config.merge service_config
            @logger.debug "Service #{service_name} configuration: #{service_config}"
            process_service service_name, service_config, service_state, service_prefix, type, metrics
          rescue RuntimeError => e
            # skipping service
            log_exception e
          end
        end
      rescue RuntimeError => e
        # skipping service type
        log_exception e
      end
    end

    def log_exception(e)
      @logger.log (e.class == Scaltainer::Warning ? Logger::WARN : Logger::ERROR), e.message
    end

    def process_service(service_name, config, state, prefix, type, metrics)
      full_service_name = prefix ? "#{prefix}_#{service_name}" : service_name
      service = get_service full_service_name
      @logger.debug "Found service at docker with name '#{service_name}' and id '#{service.id}'"
      current_replicas = get_service_replicas service
      @logger.debug "Service #{service_name} is currently configured for #{current_replicas} replica(s)"
      metric = metrics[service_name]
      raise Scaltainer::Warning.new("Configured service '#{service_name}' not found in metrics endpoint") unless metric
      desired_replicas = type.determine_desired_replicas metric, config, current_replicas
      @logger.debug "Desired number of replicas for service #{service_name} is #{desired_replicas}"
      adjusted_replicas = type.adjust_desired_replicas(desired_replicas, config)
      @logger.debug "Desired number of replicas for service #{service_name} is adjusted to #{adjusted_replicas}"
      replica_diff = desired_replicas - current_replicas
      type.yield_to_scale(replica_diff, config, state, metric,
        service_name, @logger) do
          scale_out service, current_replicas, adjusted_replicas
        end
    end

    def scale_out(service, current_replicas, desired_replicas)
      return if current_replicas == desired_replicas
      # send scale command to docker
      service_name = service.info['Spec']['Name']
      @logger.info "Scaling #{service_name} from #{current_replicas} to #{desired_replicas}"
      begin
        service.scale desired_replicas
      rescue => e
        raise NetworkError.new "Could not scale service #{service_name} due to docker engine error at #{Docker.url}.\n#{e.message}"
      end
    end

  end # class
end # module
