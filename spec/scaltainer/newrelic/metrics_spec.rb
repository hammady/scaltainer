require 'spec_helper'

include Newrelic

describe Metrics do
  describe '#get_avg_response_time' do
    let(:app_id) { 100 }
    let(:http_query_regex) {/HttpDispatcher/}
    let(:webfe_query_regex) {/WebFrontend\/QueueTime/}
    let(:from){ Time.now }
    let(:to){ Time.now }

    before {
      Excon.stub({
        method: :get, host: 'api.newrelic.com',
        path: "/v2/applications/#{app_id}/metrics/data.json"
      }, lambda {|request_params|
        if request_params[:query].match(http_query_regex)
          {body: http_response_body, status: http_response_code}
        elsif request_params[:query].match(webfe_query_regex)
          {body: webfe_response_body, status: webfe_response_code}
        end
      })
    }

    context 'when no metrics returned' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[]}}'
      }
      let(:http_response_code) { 200 }
      let(:webfe_response_body) {
        '{"metric_data":{"metrics":[]}}'
      }
      let(:webfe_response_code) { 200 }
      let(:nan) { 0.0/0 }

      it 'returns NaN' do
        expect(Newrelic::Metrics.new(nil).get_avg_response_time(app_id, from, to).nan?).to \
          eq true
      end
    end

    context 'when error returned' do
      let(:http_response_body) {
        '{"error":{"title":"NEWRELIC_ERROR"}}'
      }
      let(:http_response_code) { 400 }
      let(:webfe_response_body) {
        '{"error":{"title":"NEWRELIC_ERROR"}}'
      }
      let(:webfe_response_code) { 400 }
      let(:nan) { 0.0/0 }

      it 'raises the error' do
        expect{Newrelic::Metrics.new(nil).get_avg_response_time(app_id, from, to)}.to \
          raise_error /NEWRELIC_ERROR/
      end
    end

    context 'when valid metrics returned' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[{"values":{
          "average_call_time":100,"call_count":100000}}]}]}}'
      }
      let(:http_response_code) { 200 }
      let(:webfe_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[{"values":{
          "average_response_time":10,"call_count":100000}}]}]}}'
      }
      let(:webfe_response_code) { 200 }

      it 'computes correct average response time' do
        expect(Newrelic::Metrics.new(nil).get_avg_response_time(app_id, from, to)).to \
          eq 110
      end
    end
  end
end # describe Metrics