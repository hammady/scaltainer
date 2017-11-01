require 'spec_helper'

include Scaltainer

describe ServiceTypeBase do
  let(:base_type) { ServiceTypeBase.new(nil) }

  describe '.initialize' do
    context 'when no app_endpoint is specified' do
      it 'leaves instance variable as nil' do
        expect(base_type.instance_variable_get(:@app_endpoint)).to \
          be_nil
      end
    end

    context 'when a non empty app_endpoint is specified' do
      let(:app_endpoint) { 'value' }
      let(:base_type) { ServiceTypeBase.new(app_endpoint) }
      
      it 'sets instance variable to the specified value' do
        expect(base_type.instance_variable_get(:@app_endpoint)).to \
          eq app_endpoint
      end
    end

    context 'when a non empty app_endpoint is specified having $HIREFIRE_TOKEN' do
      let(:app_endpoint) { 'prefix $HIREFIRE_TOKEN suffix' }
      let(:base_type) { ServiceTypeBase.new(app_endpoint) }

      context 'when no environment variable set' do
        let(:token) { 'hftoken' }
        let(:processed_endpoint) { 'prefix hftoken suffix' }

        before {
          allow(ENV).to receive(:[]).with('HIREFIRE_TOKEN') { token }
        }

        it 'sets instance variable to the specified value after replacing the token with corresponding environment value' do
          expect(base_type.instance_variable_get(:@app_endpoint)).to \
            eq processed_endpoint
        end
      end

      context 'when a non-empty environment variable set' do
        let(:processed_endpoint) { 'prefix  suffix' }

        before {
          allow(ENV).to receive(:[]).with('HIREFIRE_TOKEN') { nil }
        }

        it 'sets instance variable to the specified value after replacing the token with corresponding environment value' do
          expect(base_type.instance_variable_get(:@app_endpoint)).to \
            eq processed_endpoint
        end
      end
    end
  end # describe .initialize

  describe '#get_metrics' do
    context 'when no services given' do
      let(:services) { nil }

      it 'raises ConfigurationError' do
        expect{base_type.get_metrics(services)}.to \
          raise_exception Scaltainer::Warning, /No services found/
      end
    end

    context 'when empty services given' do
      let(:services) { {} }

      it 'raises ConfigurationError' do
        expect{base_type.get_metrics(services)}.to \
          raise_exception Scaltainer::Warning, /No services found/
      end
    end

    context 'when non-empty services given' do
      let(:services) { {w1: {}} }

      it 'does not raise errors' do
        expect{base_type.get_metrics(services)}.not_to \
          raise_exception
      end
    end
  end # describe #get_metrics

  describe '#determine_desired_replicas' do
    context 'when no metric given' do
      it 'raises ConfigurationError' do
        expect{base_type.determine_desired_replicas(nil, {}, nil)}.to \
          raise_exception ConfigurationError, /No metric found/
      end
    end

    context 'when no service_config given' do
      it 'raises ConfigurationError' do
        expect{base_type.determine_desired_replicas(0, nil, nil)}.to \
          raise_exception ConfigurationError, /No configuration found/
      end
    end

    context 'when both metric and service_config given' do
      it 'does not raise errors' do
        expect{base_type.determine_desired_replicas(0, {}, nil)}.not_to \
          raise_exception
      end
    end
  end # describe #determine_desired_replicas

  describe '#adjust_desired_replicas' do
    it 'is pending'
  end # describe #adjust_desired_replicas
end # describe ServiceTypeBase
