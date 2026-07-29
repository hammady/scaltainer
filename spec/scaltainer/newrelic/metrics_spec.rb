require 'spec_helper'

include Newrelic

describe Metrics do
  describe '#get_avg_response_time' do
    let(:app_id) { 100 }
    let(:http_query_regex) {/HttpDispatcher/}
    let(:webfe_query_regex) {/WebFrontend\/QueueTime/}
    let(:from){ Time.now }
    let(:to){ Time.now }
    let(:metrics) { Newrelic::Metrics.new(nil) }

    let(:http_response_code) { 200 }
    let(:webfe_response_code) { 200 }
    let(:webfe_response_body) {
      '{"metric_data":{"metrics":[{"timeslices":[{"values":{
        "average_response_time":10,"call_count":100000}}]}]}}'
    }

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
      let(:webfe_response_body) {
        '{"metric_data":{"metrics":[]}}'
      }

      it 'returns nil rather than a metric value' do
        expect(metrics.get_avg_response_time(app_id, from, to)).to be_nil
      end
    end

    context 'when no timeslices returned for the window' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[]}]}}'
      }

      it 'returns nil rather than a metric value' do
        expect(metrics.get_avg_response_time(app_id, from, to)).to be_nil
      end
    end

    context 'when the application dispatched nothing in the window' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[{"values":{
          "average_call_time":0,"call_count":0}}]}]}}'
      }

      it 'returns nil rather than dividing by zero' do
        expect(metrics.get_avg_response_time(app_id, from, to)).to be_nil
      end
    end

    context 'when queue time is not reported' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[{"values":{
          "average_call_time":100,"call_count":100000}}]}]}}'
      }
      let(:webfe_response_body) {
        '{"metric_data":{"metrics":[]}}'
      }

      it 'reports the dispatcher time without a queue time correction' do
        expect(metrics.get_avg_response_time(app_id, from, to)).to eq 100
      end
    end

    context 'when a permanent error is returned' do
      let(:http_response_body) {
        '{"error":{"title":"NEWRELIC_ERROR"}}'
      }
      let(:webfe_response_body) {
        '{"error":{"title":"NEWRELIC_ERROR"}}'
      }
      let(:http_response_code) { 401 }
      let(:webfe_response_code) { 401 }

      it 'raises ConfigurationError' do
        expect{metrics.get_avg_response_time(app_id, from, to)}.to \
          raise_exception Scaltainer::ConfigurationError, /NEWRELIC_ERROR/
      end
    end

    context 'when a transient error is returned' do
      let(:http_response_body) {
        '{"error":{"title":"NEWRELIC_ERROR"}}'
      }
      let(:webfe_response_body) {
        '{"error":{"title":"NEWRELIC_ERROR"}}'
      }
      let(:http_response_code) { 503 }
      let(:webfe_response_code) { 503 }

      it 'raises NetworkError' do
        expect{metrics.get_avg_response_time(app_id, from, to)}.to \
          raise_exception Scaltainer::NetworkError, /NEWRELIC_ERROR/
      end
    end

    context 'when a non json response is returned' do
      let(:http_response_body) { 'not json' }
      let(:webfe_response_body) { 'not json' }

      it 'raises NetworkError' do
        expect{metrics.get_avg_response_time(app_id, from, to)}.to \
          raise_exception Scaltainer::NetworkError, /non json response/
      end
    end

    context 'when an unexpected payload is returned' do
      let(:http_response_body) { '{"metric_data":"unexpected"}' }
      let(:webfe_response_body) { '{"metric_data":"unexpected"}' }

      it 'raises NetworkError' do
        expect{metrics.get_avg_response_time(app_id, from, to)}.to \
          raise_exception Scaltainer::NetworkError, /unexpected payload/
      end
    end

    context 'when a metric value is not numeric' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[{"values":{
          "average_call_time":100,"call_count":"lots"}}]}]}}'
      }

      it 'raises NetworkError' do
        expect{metrics.get_avg_response_time(app_id, from, to)}.to \
          raise_exception Scaltainer::NetworkError, /non numeric call_count/
      end
    end

    context 'when valid metrics returned' do
      let(:http_response_body) {
        '{"metric_data":{"metrics":[{"timeslices":[{"values":{
          "average_call_time":100,"call_count":100000}}]}]}}'
      }

      it 'computes correct average response time' do
        expect(metrics.get_avg_response_time(app_id, from, to)).to eq 110
      end
    end
  end
end # describe Metrics
