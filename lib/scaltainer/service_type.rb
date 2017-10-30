module Scaltainer
  class ServiceType
    def initialize(app_endpoint)
      @app_endpoint = app_endpoint
    end

    def get_metrics(services)
      services_count = services.keys.length rescue 0
      raise Warning.new('No services found for requested type') if services_count == 0
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
      # TODO get from NR or whatever
      {"web" => 400, "webapi" => 50, "nginx" => 50}
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
      # TODO get current metrics from app endpoint
      #@app_endpoint
      m = [{:name=>"worker", :quantity=>10}, {:name=>"info_extractor", :quantity=>60}, {:name=>"sim_calculator", :quantity=>0}, {:name=>"prediction", :quantity=>2}, {:name=>"indexer", :quantity=>0}, {:name=>"long_indexer", :quantity=>1}, {:name=>"dedup", :quantity=>0}]
      m.reduce({}){|hash, item| hash.merge!({item[:name] => item[:quantity]})}
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      super
      desired_replicas = (metric * 1.0 / service_config["ratio"]).ceil
    end
  end
end

