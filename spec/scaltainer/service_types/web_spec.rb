require 'spec_helper'

include Scaltainer

describe ServiceTypeWeb do
  describe '#get_metrics' do
    let(:web_type) { ServiceTypeWeb.new }
    let(:services) { 
      {
        "w1" => {"newrelic_app_id" => 'id1'},
        "w2" => {"newrelic_app_id" => 'id2'}
      }
    }

    before {
      allow(ENV).to receive(:[]).with("RESPONSE_TIME_WINDOW").and_return(nil)
    }

    context 'when NEW_RELIC_LICENSE_KEY is missing' do
      before {
        allow(ENV).to receive(:[]).with("NEW_RELIC_LICENSE_KEY").and_return(nil)
      }

      it 'raises ConfigurationError' do
        expect{web_type.get_metrics(services)}.to \
          raise_exception ConfigurationError, /NEW_RELIC_LICENSE_KEY not set/
      end
    end

    context 'when NEW_RELIC_LICENSE_KEY is specified' do
      let(:nr_mock) { double(Newrelic::Metrics) }

      before {
        allow(ENV).to receive(:[]).with("NEW_RELIC_LICENSE_KEY"){ 'secret' }
        allow(Newrelic::Metrics).to receive(:new).with('secret'){ nr_mock }
      }

      context 'when any of the services does not have a newrelic_app_id in config' do
        let(:services) { {"w1" => {"newrelic_app_id" => 'id1'}, "w2" => {}} }
  
        before {
          allow(nr_mock).to receive(:get_avg_response_time){ 0 }
        }

        it 'raises ConfigurationError' do
          expect{web_type.get_metrics(services)}.to \
            raise_exception ConfigurationError, /w2 does not have .* newrelic_app_id/
        end
      end

      context 'when any of the services fail to retrieve its metrics' do
        before {
          allow(nr_mock).to receive(:get_avg_response_time).with('id1', anything, anything) {
            0
          }
          allow(nr_mock).to receive(:get_avg_response_time).with('id2', anything, anything) {
            raise SocketError.new
          }
        }

        it 'raises NetworkError' do
          expect{web_type.get_metrics(services)}.to \
            raise_exception NetworkError, /Could not retrieve metrics/
        end
      end

      context 'when no errors raised' do
        before {
          allow(nr_mock).to receive(:get_avg_response_time).with('id1', anything, anything) {
            10
          }
          allow(nr_mock).to receive(:get_avg_response_time).with('id2', anything, anything) {
            20
          }
        }

        it 'gets metrics for all services' do
          expect(web_type.get_metrics(services)).to \
            eq({"w1" => 10, "w2" => 20})
        end
      end
    end
  end # describe #get_metrics

  describe '#determine_desired_replicas' do
    it 'is pending'
  end # describe #determine_desired_replicas

  describe '#to_s' do
    it 'returns a human readable string' do
      expect("#{ServiceTypeWeb.new}").to eq "Web"
    end
  end # describe #to_s
end # describe ServiceTypeWeb
