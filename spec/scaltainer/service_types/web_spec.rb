require 'spec_helper'

include Scaltainer

describe ServiceTypeWeb do
  let(:web_type) { ServiceTypeWeb.new }

  describe '#get_metrics' do
    let(:services) { {
      "w1" => {"newrelic_app_id" => 'id1'},
      "w2" => {"newrelic_app_id" => 'id2'}
    } }

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
    context 'when max_response_time is missing in config' do
      let(:config) { {"min_response_time" => 0} }

      it 'raises ConfigurationError' do
        expect{web_type.determine_desired_replicas(0, config, nil)}.to \
          raise_exception ConfigurationError, /Missing max_response_time/
      end
    end

    context 'when min_response_time is missing in config' do
      let(:config) { {"max_response_time" => 0} }

      it 'raises ConfigurationError' do
        expect{web_type.determine_desired_replicas(0, config, nil)}.to \
          raise_exception ConfigurationError, /Missing min_response_time/
      end
    end

    context 'when min_response_time and max_response_time are not in order' do
      let(:config) { {"min_response_time" => 100, "max_response_time" => 50} }

      it 'raises ConfigurationError' do
        expect{web_type.determine_desired_replicas(0, config, nil)}.to \
          raise_exception ConfigurationError, /are not in order/
      end
    end

    context 'when config is ok' do
      let(:config) { {
        "min_response_time" => 50,
        "max_response_time" => 100,
        "upscale_quantity" => 2,
        "downscale_quantity" => 3
      } }

      context 'metric is above max_response_time' do
        it 'increases current replicas by upscale quantity' do
          expect(web_type.determine_desired_replicas(200, config, 5)).to eq 7
        end
      end

      context 'metric is below min_response_time' do
        it 'decreases current replicas by downscale quantity' do
          expect(web_type.determine_desired_replicas(30, config, 5)).to eq 2
          # it is ok to return a negative number, will be bounded later
        end          
      end

      context 'metric is between min_response_time and max_response_time' do
        it 'does not change current replicas' do
          expect(web_type.determine_desired_replicas(75, config, 5)).to eq 5
        end
      end

      context 'metric is NaN' do
        it 'does not change current replicas' do
          # this happens when app is idle, call_count = 0
          expect(web_type.determine_desired_replicas(0.0/0, config, 5)).to eq 5
        end
      end
    end
  end # describe #determine_desired_replicas

  describe '#to_s' do
    it 'returns a human readable string' do
      expect("#{ServiceTypeWeb.new}").to eq "Web"
    end
  end # describe #to_s
end # describe ServiceTypeWeb
