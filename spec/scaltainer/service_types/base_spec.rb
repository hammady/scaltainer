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
    context 'when desired_replicas below min' do
      it 'adjusts desired_replicas to min' do
        expect(base_type.adjust_desired_replicas(0, {"min" => 1})).to \
          eq 1
      end
    end

    context 'when desired_replicas above max' do
      it 'adjusts desired_replicas to max' do
        expect(base_type.adjust_desired_replicas(15, {"max" => 10, "min" => 0})).to \
          eq 10
      end
    end

    context 'when no max configured' do
      it 'does not change desired_replicas' do
        expect(base_type.adjust_desired_replicas(99999, {"min" => 0})).to \
          eq 99999
      end
    end

    context 'when desired_replicas between min and max' do
      it 'does not change desired_replicas' do
        expect(base_type.adjust_desired_replicas(5, {"max" => 10, "min" => 0})).to \
          eq 5
      end
    end
  end # describe #adjust_desired_replicas

  describe '#yield_to_scale' do
    context 'when scaling up' do
      it 'increments upscale sensitivity level and resets downscale sensitivity level'

      context 'when reached required upscale sensitivity level' do
        it 'yields to scale and resets upscale sensitivity level'
      end

      context 'when blocked by lower upscale sensitivity level' do
        it 'does not yield'

        it 'logs a debug message'
      end
    end

    context 'when scaling down' do
      context 'when can scale down' do
        it 'increments downscale sensitivity level and resets upscale sensitivity level'

        context 'when reached required downscale sensitivity level' do
          it 'yields to scale and resets downscale sensitivity level'
        end

        context 'when blocked by lower downscale sensitivity level' do
          it 'does not yield'
          
          it 'logs a debug message'
        end
      end

      context 'when cannot scale down' do
        it 'does not change sensitivity levels'

        it 'logs a debug message'
      end
    end

    context 'when not scaling' do
      it 'resets both sensitivity levels'

      it 'logs an info message'
    end
  end # describe #yield_to_scale

  describe '#can_scale_down?' do
    let(:worker_type) { ServiceTypeWorker.new }
    let(:web_type) { ServiceTypeWeb.new }

    context 'when of type web' do
      it 'returns true' do
        expect(web_type.send(:can_scale_down?, 10, {})).to be true
      end
    end

    context 'when scaling down to 0' do
      it 'returns true' do
        expect(worker_type.send(:can_scale_down?, 0, {})).to be true
      end
    end

    context 'when service is decrementable in config' do
      it 'returns true' do
        expect(worker_type.send(:can_scale_down?, 10, {"decrementable" => true})).to be true
      end
    end

    context 'when not of type Web and not scaling to 0 and not decrementable' do
      it 'returns false' do
        expect(worker_type.send(:can_scale_down?, 10, {})).not_to be true
      end
    end
  end # describe #can_scale_down

  describe '#to_s' do
    it 'returns a human readable string' do
      expect("#{ServiceTypeBase.new(nil)}").to eq "Base"
    end
  end # describe #to_s
end # describe ServiceTypeBase
