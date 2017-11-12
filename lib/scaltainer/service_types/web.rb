module Scaltainer
  class ServiceTypeWeb < ServiceTypeBase
    def initialize(app_endpoint = nil)
      super
    end

    def get_metrics(services)
      super
      nr_key = ENV['NEW_RELIC_LICENSE_KEY']
      raise ConfigurationError.new 'NEW_RELIC_LICENSE_KEY not set in environment' unless nr_key
      nr = Newrelic::Metrics.new nr_key
      to = Time.now
      from = to - (ENV['RESPONSE_TIME_WINDOW'] || '5').to_i * 60

      services.reduce({}) do |hash, (service_name, service_config)|
        app_id = service_config["newrelic_app_id"]
        raise ConfigurationError.new "Service #{service_name} does not have a corresponding newrelic_app_id" unless app_id

        begin
          metric = nr.get_avg_response_time app_id, from, to
        rescue => e
          raise NetworkError.new "Could not retrieve metrics from New Relic API for #{service_name}: #{e.message}"
        end

        hash.merge!(service_name => metric)
      end
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      super
      raise ConfigurationError.new "Missing max_response_time in web service configuration" unless service_config["max_response_time"]
      raise ConfigurationError.new "Missing min_response_time in web service configuration" unless service_config["min_response_time"]
      unless service_config["min_response_time"] <= service_config["max_response_time"]
        raise ConfigurationError.new "min_response_time and max_response_time are not in order"
      end
      desired_replicas = if metric > service_config["max_response_time"]
        current_replicas + service_config["upscale_quantity"]
      elsif metric < service_config["min_response_time"]
        current_replicas - service_config["downscale_quantity"]
      else
        current_replicas
      end
    end

    def to_s
      "Web"
    end
  end
end
