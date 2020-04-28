require "yaml"
require 'socket'
require 'prometheus/client'
require 'prometheus/client/push'

module Scaltainer
  class Runner
    def initialize(configfile, statefile, logger, wait, orchestrator, pushgateway)
      @orchestrator = orchestrator
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
      Docker.logger = @logger if orchestrator == :swarm
      state = get_state(statefile) || {}
      endpoint = config["endpoint"]
      service_type_web = ServiceTypeWeb.new(endpoint)
      service_type_worker = ServiceTypeWorker.new(endpoint)
      register_pushgateway(pushgateway) if pushgateway
      namespace = config["namespace"] || config["stack_name"]
      loop do
        run config, state, service_type_web, service_type_worker, namespace
        save_state statefile, state
        sync_pushgateway(namespace, state) if pushgateway
        sleep wait
        break if wait == 0
      end
    end

    private

    def run(config, state, service_type_web, service_type_worker, namespace)
      iterate_services config["web_services"], namespace, service_type_web, state
      iterate_services config["worker_services"], namespace, service_type_worker, state
    end

    def get_state(statefile)
      YAML.load_file statefile if File.exists? statefile
    end

    def save_state(statefile, state)
      File.write(statefile, state.to_yaml)
    end

    def iterate_services(services, namespace, type, state)
      begin
        metrics = type.get_metrics services
        @logger.debug "Retrieved metrics for #{type} resources: #{metrics}"
        services.each do |service_name, service_config|
          begin
            state[service_name] ||= {}
            service_state = state[service_name]
            @logger.debug "Resource #{service_name} in namespace #{namespace} currently has state: #{service_state}"
            service_config = @default_service_config.merge service_config
            @logger.debug "Resource #{service_name} in namespace #{namespace} configuration: #{service_config}"
            process_service service_name, service_config, service_state, namespace, type, metrics
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

    def process_service(service_name, config, state, namespace, type, metrics)
      service = get_service service_name, namespace
      @logger.debug "Found #{service.type} at orchestrator with name '#{service.name}' and id '#{service.id}'"
      current_replicas = service.get_replicas
      @logger.debug "#{service.type.capitalize} #{service.name} is currently configured for #{current_replicas} replica(s)"
      metric = metrics[service.name]
      raise Scaltainer::Warning.new("Configured #{service.type} '#{service.name}' not found in metrics endpoint") unless metric
      state["metric"] = metric
      state["service_type"] = type.to_s
      desired_replicas = type.determine_desired_replicas metric, config, current_replicas
      @logger.debug "Desired number of replicas for #{service.type} #{service.name} is #{desired_replicas}"
      adjusted_replicas = type.adjust_desired_replicas(desired_replicas, config)
      @logger.debug "Desired number of replicas for #{service.type} #{service.name} is adjusted to #{adjusted_replicas}"
      replica_diff = adjusted_replicas - current_replicas
      state["replicas"] = current_replicas
      type.yield_to_scale(replica_diff, config, state, metric,
        service.name, @logger) do
          scale_out service, current_replicas, adjusted_replicas
          state["replicas"] = adjusted_replicas
        end
    end

    def get_service(service_name, namespace)
      begin
        service = if @orchestrator == :swarm
          DockerService.new service_name, namespace
        elsif @orchestrator == :kubernetes
          KubeResource.new service_name, namespace
        end
      rescue => e
        raise NetworkError.new "Could not find resource with name #{service_name} in namespace #{namespace}: #{e.message}"
      end
      raise ConfigurationError.new "Unknown resource: #{service_name} in namespace #{namespace}" unless service
      service
    end

    def scale_out(service, current_replicas, desired_replicas)
      return if current_replicas == desired_replicas
      # send scale command to orchestrator
      @logger.info "Scaling #{service.type} #{service.name} from #{current_replicas} to #{desired_replicas}"
      begin
        service.set_replicas desired_replicas
      rescue => e
        raise NetworkError.new "Could not scale #{service.type} #{service.name} due to error: #{e.message}"
      end
    end

    def register_pushgateway(pushgateway)
      @registry = Prometheus::Client.registry
      @web_replicas_gauge = @registry.gauge(:scaltainer_web_replicas_total, docstring: 'Scaltainer controller replicas for web services', labels: [:controller, :namespace])
      @worker_replicas_gauge = @registry.gauge(:scaltainer_worker_replicas_total, docstring: 'Scaltainer controller replicas for worker services', labels: [:controller, :namespace])
      @web_metrics_gauge = @registry.gauge(:scaltainer_web_response_time_seconds, docstring: 'Scaltainer controller response time metric in seconds', labels: [:controller, :namespace])
      @worker_metrics_gauge = @registry.gauge(:scaltainer_worker_queue_size_total, docstring: 'Scaltainer controller queue size metric', labels: [:controller, :namespace])
      @ticks_counter = @registry.counter(:scaltainer_ticks_total, docstring: 'Scaltainer ticks', labels: [:namespace])

      @pushgateway = Prometheus::Client::Push.new("scaltainer", Socket.gethostname, "http://#{pushgateway}")
    end

    def sync_pushgateway(namespace, state)
      @logger.debug("Now syncing state #{state} in namespace #{namespace}")
      factor = 1
      state.each do |service, state|
        if state["service_type"] == 'Web'
          replicas_gauge = @web_replicas_gauge
          metrics_gauge = @web_metrics_gauge
          factor = 0.001
        else
          replicas_gauge = @worker_replicas_gauge
          metrics_gauge = @worker_metrics_gauge
        end
        replicas_gauge.set(state["replicas"], labels: {namespace: namespace, controller: service})
        metrics_gauge.set(state["metric"] * factor, labels: {namespace: namespace, controller: service})
      end
      @ticks_counter.increment(labels: {namespace: namespace})
      begin
        @pushgateway.add(@registry)
      rescue => e
        @logger.warn "[#{e.class}] Error pushing metrics to the configured Prometheus Push Gateway: #{e.message}"
      end
      @logger.info "Pushed metrics successfully to the configured Prometheus Push Gateway"
    end

  end # class
end # module
