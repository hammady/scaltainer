require 'spec_helper'

include Newrelic

describe Metrics do
  describe '#get_avg_response_time' do
    let(:app_id) { 100 }
    let(:http_query_regex) {/HttpDispatcher/}
    let(:webfe_query_regex) {/WebFrontend\/QueueTime/}
    let(:http_response) {
      '{"metric_data":{"metrics":[{"timeslices":[{"values":{
        "average_call_time":100,"call_count":100000}}]}]}}'
    }
    let(:webfe_response) {
      '{"metric_data":{"metrics":[{"timeslices":[{"values":{
        "average_response_time":10,"call_count":100000}}]}]}}'
    }
    let(:from){ Time.now }
    let(:to){ Time.now }

    before {
      Excon.stub({
        method: :get, host: 'api.newrelic.com',
        path: "/v2/applications/#{app_id}/metrics/data.json"
      }, lambda {|request_params|
        if request_params[:query].match(http_query_regex)
          {body: http_response, status: 200}
        elsif request_params[:query].match(webfe_query_regex)
          {body: webfe_response, status: 200}
        end
      })
    }

    it 'computes correct average response time' do
      expect(Newrelic::Metrics.new(nil).get_avg_response_time(app_id, from, to)).to \
        eq 110
    end
  end
end # describe Metrics