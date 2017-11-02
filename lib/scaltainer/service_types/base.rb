module Scaltainer
  class ServiceTypeBase
    def initialize(app_endpoint)
      @app_endpoint = app_endpoint.sub('$HIREFIRE_TOKEN', ENV['HIREFIRE_TOKEN'] || '') if app_endpoint
    end

    def get_metrics(services)
      services_count = services.keys.length rescue 0
      raise Scaltainer::Warning.new "No services found for #{self.class.name}" if services_count == 0
    end

    def determine_desired_replicas(metric, service_config, current_replicas)
      raise ConfigurationError.new 'No metric found for requested service' unless metric
      raise ConfigurationError.new 'No configuration found for requested service' unless service_config
    end

    def adjust_desired_replicas(desired_replicas, config)
      desired_replicas = [config["max"], desired_replicas].min if config["max"]
      [config["min"], desired_replicas].max
    end

    def yield_to_scale(replica_diff, config, state, metric, service_name, logger)
      # Force up/down when below/above min/max?
      # one could argue that this could only happen on first deployment or when manually
      # scaled outside the scope of scaltainer. It is OK in this case to still apply sensitivity rules
      if replica_diff > 0
        # breach: change state and scale up
        state["upscale_sensitivity"] ||= 0
        state["upscale_sensitivity"] += 1
        state["downscale_sensitivity"] = 0
        if state["upscale_sensitivity"] >= config["upscale_sensitivity"]
          yield
          state["upscale_sensitivity"] = 0
        else
          logger.debug "Scaling up of service #{service_name} blocked by upscale_sensitivity at level " +
            "#{state["upscale_sensitivity"]} while level #{config["upscale_sensitivity"]} is required"
        end
      elsif replica_diff < 0  # TODO force down when above max?
        # breach: change state and scale down
        if can_scale_down? metric, config
          state["downscale_sensitivity"] ||= 0
          state["downscale_sensitivity"] += 1
          state["upscale_sensitivity"] = 0
          if state["downscale_sensitivity"] >= config["downscale_sensitivity"]
            yield
            state["downscale_sensitivity"] = 0
          else
            logger.debug "Scaling down of service #{service_name} blocked by downscale_sensitivity at level " +
              "#{state["downscale_sensitivity"]} while level #{config["downscale_sensitivity"]} is required"
          end
        else
          logger.debug "Scaling down of service #{service_name} to #{metric} replicas blocked by a non-decrementable non-web config"
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

    private

    def can_scale_down?(metric, config)
      self.class == ServiceTypeWeb || metric == 0 || config["decrementable"]
    end
  end
end
