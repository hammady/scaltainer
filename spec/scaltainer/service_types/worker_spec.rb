require 'spec_helper'

include Scaltainer

describe ServiceTypeWorker do
  describe '#get_metrics' do
    let(:endpoint_host) { 'my_endpoint.com' }
    let(:endpoint) { "http://#{endpoint_host}/" }
    let(:worker_type) { ServiceTypeWorker.new endpoint }
    let(:services) { {w1: {}, w2: {}} }

    before {
      Excon.stub({
        method: :get, host: endpoint_host, path: '/'
      }, {
        body: response_body, status: 200
      })
    }

    context 'when endpoint returns valid json' do
      let(:response_body) {
        '[{"name":"worker1","quantity":10},{"name":"worker2","quantity":20}]'
      }
      let(:parsed_body) {
        {"worker1" => 10, "worker2" => 20}
      }

      it 'gets metrics from app endpoint' do
        expect(worker_type.get_metrics(services)).to eq parsed_body
      end
    end

    context 'when endpoint returns syntactically invalid json' do
      let(:response_body) {
        'not json'
      }

      it 'raises ConfigurationError' do
        expect{worker_type.get_metrics(services)}.to raise_exception ConfigurationError
      end
    end

    context 'when endpoint returns semantically invalid json' do
      let(:response_body) {
        '{"name":"worker1","quantity":10}'
      }

      it 'raises ConfigurationError' do
        expect{worker_type.get_metrics(services)}.to raise_exception ConfigurationError
      end
    end

    context 'when connection fails' do
      it 'raises NetworkError'
    end

  end

  describe '#determine_desired_replicas' do
    it 'raises ConfigurationError if ratio is missing'

    it 'computes desired replicas correctly'
  end
end
