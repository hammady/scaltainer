module Scaltainer
  class ServiceTypeWorker < ServiceTypeBase
    def initialize(app_endpoint = nil)
      super
    end

    def get_metrics(services)
      super
      begin
        response = Excon.get(@app_endpoint)
        m = JSON.parse(response.body)
        m.reduce({}){|hash, item| hash.merge!({item["name"] => item["quantity"]})}
      rescue JSON::ParserError => e
        raise ConfigurationError.new "app_endpoint returned non json response: #{response.body[0..128]}"
      rescue TypeError => e
        raise ConfigurationError.new "app_endpoint returned unexpected json response: #{response.body[0..128]}"
      rescue => e
        raise NetworkError.new "Could not retrieve metrics from application endpoint: #{@app_endpoint}.\n#{e.message}"
      end
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      super
      raise ConfigurationError.new "Missing ratio in worker service configuration" unless service_config["ratio"]
      if !metric.is_a?(Fixnum) || metric < 0
        raise ConfigurationError.new "#{metric} is an invalid metric value, must be a non-negative number" 
      end
      desired_replicas = (metric * 1.0 / service_config["ratio"]).ceil
    end

    def to_s
      "Worker"
    end
  end
end
