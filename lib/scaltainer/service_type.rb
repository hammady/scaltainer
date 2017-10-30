module Scaltainer
  class ServiceType
    def initialize(app_endpoint)
      @app_endpoint = app_endpoint.sub('$HIREFIRE_TOKEN', ENV['HIREFIRE_TOKEN'] || '') if app_endpoint
    end

    def get_metrics(services)
      services_count = services.keys.length rescue 0
      raise Warning.new("No services found for #{self.class.name}") if services_count == 0
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      raise ConfigurationError.new('No metric found for requested service') unless metric
      raise ConfigurationError.new('No configuration found for requested service') unless service_config
    end
  end

  class ServiceTypeWeb < ServiceType
    def initialize(app_endpoint = nil)
      super
    end

    def get_metrics(services)
      super
      nr_key = ENV['NEW_RELIC_LICENSE_KEY']
      raise ConfigurationError.new('NEW_RELIC_LICENSE_KEY not set in environment') unless nr_key
      nr = Newrelic::Metrics.new nr_key
      time_window = (ENV['RESPONSE_TIME_WINDOW'] || '5').to_i

      services.reduce({}) do |hash, (service_name, service_config)|
        app_id = service_config["newrelic_app_id"]
        raise ConfigurationError.new("Service #{service_name} does not have a corresponding newrelic_app_id") unless app_id
        to = Time.now
        from = to - time_window * 60

        begin
          metric = nr.get_avg_response_time app_id, from, to
        rescue => e
          raise NetworkError.new("Could not retrieve metrics from New Relic API for #{service_name}\n#{e.message}")
        end

        hash.merge!(service_name => metric)
      end
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      super
      desired_replicas = if metric > service_config["max_response_time"]
        current_replicas + service_config["upscale_quantity"]
      elsif metric < service_config["min_response_time"]
        current_replicas - service_config["downscale_quantity"]
      else
        current_replicas
      end
    end
  end

  class ServiceTypeWorker < ServiceType
    def initialize(app_endpoint = nil)
      super
    end

    def get_metrics(services)
      super
      begin
        response = Excon.get(@app_endpoint)
      rescue => e
        raise NetworkError.new("Could not retrieve metrics from application endpoint: #{@app_endpoint}\n#{e.message}")
      end
      m = JSON.parse(response.body)
      m.reduce({}){|hash, item| hash.merge!({item["name"] => item["quantity"]})}
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      super
      desired_replicas = (metric * 1.0 / service_config["ratio"]).ceil
    end
  end
end

