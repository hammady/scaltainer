module Scaltainer
  class ServiceTypeBase
    def initialize(app_endpoint)
      @app_endpoint = app_endpoint.sub('$HIREFIRE_TOKEN', ENV['HIREFIRE_TOKEN'] || '') if app_endpoint
    end

    def get_metrics(services)
      services_count = services.keys.length rescue 0
      raise Warning.new "No services found for #{self.class.name}" if services_count == 0
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      raise ConfigurationError.new 'No metric found for requested service' unless metric
      raise ConfigurationError.new 'No configuration found for requested service' unless service_config
    end

    def to_s
      "Abstract"
    end
  end
end
