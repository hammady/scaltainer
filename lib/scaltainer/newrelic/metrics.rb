module Newrelic
  class Metrics
    def initialize(license_key)
      @headers = {"X-Api-Key" => license_key}
      @base_url = "https://api.newrelic.com/v2"
    end

    # https://docs.newrelic.com/docs/apis/rest-api-v2/application-examples-v2/average-response-time-examples-v2
    def get_avg_response_time(app_id, from, to)
      url = "#{@base_url}/applications/#{app_id}/metrics/data.json"
      conn = Excon.new(url, persistent: true, tcp_nodelay: true)
      time_range = "from=#{from.iso8601}&to=#{to.iso8601}"
      metric_names_array = %w(
        names[]=HttpDispatcher&values[]=average_call_time&values[]=call_count
        names[]=WebFrontend/QueueTime&values[]=call_count&values[]=average_response_time
      )
      response_array = request(conn, metric_names_array, time_range)
      http_call_count, http_average_call_time = response_array[0]["call_count"], response_array[0]["average_call_time"]
      webfe_call_count, webfe_average_response_time = response_array[1]["call_count"], response_array[1]["average_response_time"]

      http_average_call_time + (1.0 * webfe_call_count * webfe_average_response_time / http_call_count) rescue 0.0/0
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
      responses.map {|response|
        body = JSON.parse(response.body)
        if body["error"] && body["error"]["title"]
          raise body["error"]["title"]
        else
          body["metric_data"]["metrics"][0]["timeslices"][0]["values"] rescue {}
        end
      }
    end
  end
end
