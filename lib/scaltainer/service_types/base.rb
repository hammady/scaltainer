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

    def adjust_desired_replicas(desired_replicas, current_replicas, config, state, metric, service_name, logger)
      desired_replicas = [config["max"], desired_replicas].min if config["max"]
      adjusted_replicas = [config["min"], desired_replicas].max
      logger.debug "Desired number of replicas for service #{service_name} is adjusted to #{adjusted_replicas}"
      diff = adjusted_replicas - current_replicas
      # Force up/down when below/above min/max?
      # one could argue that this could only happen on first deployment or when manually
      # scaled outside the scope of scaltainer. It is OK in this case to still apply sensitivity rules
      if diff > 0
        # breach: change state and scale up
        state["upscale_sensitivity"] ||= 0
        state["upscale_sensitivity"] += 1
        state["downscale_sensitivity"] = 0
        if state["upscale_sensitivity"] >= config["upscale_sensitivity"]
          yield adjusted_replicas
          state["upscale_sensitivity"] = 0
        else
          logger.debug "Scaling up of service #{service_name} blocked by upscale_sensitivity at level " +
            "#{state["upscale_sensitivity"]} while level #{config["upscale_sensitivity"]} is required"
        end
      elsif diff < 0  # TODO force down when above max?
        # breach: change state and scale down
        if self.class == ServiceTypeWeb || metric == 0 || config["decrementable"]
          state["downscale_sensitivity"] ||= 0
          state["downscale_sensitivity"] += 1
          state["upscale_sensitivity"] = 0
          if state["downscale_sensitivity"] >= config["downscale_sensitivity"]
            yield adjusted_replicas
            state["downscale_sensitivity"] = 0
          else
            logger.debug "Scaling down of service #{service_name} blocked by downscale_sensitivity at level " +
              "#{state["downscale_sensitivity"]} while level #{config["downscale_sensitivity"]} is required"
          end
        end
      else
        # no breach, change state
        state["upscale_sensitivity"] = 0
        state["downscale_sensitivity"] = 0
        logger.info "No need to scale service #{service_name}"
      end
    end

    def to_s
      "Base"
    end
  end
end
