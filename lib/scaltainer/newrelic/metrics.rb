module Newrelic
  class Metrics
    # New Relic reports failures as an error body alongside an HTTP status.
    # These statuses mean the request can never succeed as configured (unknown
    # application id, rejected API key), so they are permanent. Anything else
    # (rate limiting, 5xx) is transient and worth retrying on the next tick.
    PERMANENT_ERROR_STATUSES = [400, 401, 403, 404].freeze

    def initialize(license_key)
      @headers = {"X-Api-Key" => license_key}
      @base_url = "https://api.newrelic.com/v2"
    end

    # https://docs.newrelic.com/docs/apis/rest-api-v2/application-examples-v2/average-response-time-examples-v2
    # Returns the average response time, or nil when New Relic holds no data for
    # the requested window. Callers must treat nil as "no metric for this
    # resource" rather than as a response time.
    def get_avg_response_time(app_id, from, to)
      url = "#{@base_url}/applications/#{app_id}/metrics/data.json"
      conn = Excon.new(url, persistent: true, tcp_nodelay: true)
      time_range = "from=#{from.iso8601}&to=#{to.iso8601}"
      metric_names_array = %w(
        names[]=HttpDispatcher&values[]=average_call_time&values[]=call_count
        names[]=WebFrontend/QueueTime&values[]=call_count&values[]=average_response_time
      )
      http_values, webfe_values = request(conn, metric_names_array, time_range)

      # an application that dispatched nothing in the window has no response time
      return nil unless http_values
      http_call_count = numeric_value http_values, "call_count"
      return nil if http_call_count.zero?
      http_average_call_time = numeric_value http_values, "average_call_time"

      # queue time is an additive correction and is absent for applications that
      # do not sit behind a request queue, in which case it contributes nothing
      webfe_call_count = webfe_values ? numeric_value(webfe_values, "call_count") : 0
      webfe_average_response_time = webfe_values ? numeric_value(webfe_values, "average_response_time") : 0

      http_average_call_time + (1.0 * webfe_call_count * webfe_average_response_time / http_call_count)
    end

  private

    def request(conn, metric_names_array, time_range)
      requests = metric_names_array.map {|metric_names|
        {
          method: :get, headers: @headers,
          query: "#{metric_names}&#{time_range}&summarize=true"
        }
      }
      responses = conn.requests requests
      responses.map {|response| extract_values response }
    end

    # Returns the values hash of the first timeslice, or nil when New Relic
    # reported no data for the metric over the requested window.
    def extract_values(response)
      body = parse_body response
      error = body["error"]
      raise_api_error response.status, error["title"] if error.is_a?(Hash) && error["title"]

      metric_data = body["metric_data"]
      metrics = metric_data.is_a?(Hash) ? metric_data["metrics"] : nil
      raise_unexpected_payload response unless metrics.is_a?(Array)
      return nil if metrics.empty?

      timeslices = metrics.first.is_a?(Hash) ? metrics.first["timeslices"] : nil
      raise_unexpected_payload response unless timeslices.is_a?(Array)
      return nil if timeslices.empty?

      values = timeslices.first.is_a?(Hash) ? timeslices.first["values"] : nil
      raise_unexpected_payload response unless values.is_a?(Hash)
      values
    end

    def parse_body(response)
      body = JSON.parse response.body
      raise_unexpected_payload response unless body.is_a?(Hash)
      body
    rescue JSON::ParserError
      raise Scaltainer::NetworkError.new \
        "New Relic API returned a non json response: #{response.body[0..128]}"
    end

    def numeric_value(values, key)
      value = values[key]
      unless value.is_a?(Numeric)
        raise Scaltainer::NetworkError.new \
          "New Relic API returned a non numeric #{key}: #{value.inspect}"
      end
      value
    end

    def raise_api_error(status, title)
      message = "New Relic API error (HTTP #{status}): #{title}"
      raise Scaltainer::ConfigurationError.new message if PERMANENT_ERROR_STATUSES.include?(status)
      raise Scaltainer::NetworkError.new message
    end

    def raise_unexpected_payload(response)
      raise Scaltainer::NetworkError.new \
        "New Relic API returned an unexpected payload: #{response.body[0..128]}"
    end
  end
end
