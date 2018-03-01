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
          raise_exception Scaltainer::Warning, /No resources found/
      end
    end

    context 'when empty services given' do
      let(:services) { {} }

      it 'raises ConfigurationError' do
        expect{base_type.get_metrics(services)}.to \
          raise_exception Scaltainer::Warning, /No resources found/
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
    let(:logger) { double(Logger) }

    before {
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
    }

    context 'when scaling up' do
      let(:diff) { 1 }
      let(:config) { {"upscale_sensitivity" => 3} }
      let(:state) { {"upscale_sensitivity" => 1} }

      it 'increments upscale sensitivity level' do
        expect{base_type.yield_to_scale(diff, config, state, nil, nil, logger){}}.to \
          change{state["upscale_sensitivity"]}.by(1)
      end

      it 'resets downscale sensitivity level' do
        expect{base_type.yield_to_scale(diff, config, state, nil, nil, logger){}}.to \
          change{state["downscale_sensitivity"]}.to(0)
      end

      context 'when reached required upscale sensitivity level' do
        let(:config) { {"upscale_sensitivity" => 3} }
        let(:state) { {"upscale_sensitivity" => 2} }

        it 'yields to scale' do
          expect{|b| base_type.yield_to_scale(diff, config, state, nil, nil, logger, &b)}.to \
            yield_control
        end

        it 'resets upscale sensitivity level' do
          expect{base_type.yield_to_scale(diff, config, state, nil, nil, logger){}}.to \
            change{state["upscale_sensitivity"]}.to(0)
        end
      end

      context 'when blocked by lower upscale sensitivity level' do
        let(:config) { {"upscale_sensitivity" => 3} }
        let(:state) { {"upscale_sensitivity" => 1} }

        it 'does not yield' do
          expect{|b| base_type.yield_to_scale(diff, config, state, nil, nil, logger, &b)}.not_to \
            yield_control
        end

        it 'logs a debug message' do
          expect(logger).to receive(:debug).with(/blocked by upscale_sensitivity/)
          base_type.yield_to_scale(diff, config, state, nil, nil, logger)
        end
      end
    end

    context 'when scaling down' do
      let(:diff) { -1 }
      let(:metric) { 5 }
      let(:config) { {} }

      context 'when can scale down' do
        let(:config) { {"downscale_sensitivity" => 3} }
        let(:state) { {"downscale_sensitivity" => 1} }

        before {
          allow(base_type).to receive(:can_scale_down?).with(metric, config){ true }
        }

        it 'increments downscale sensitivity level' do
          expect{base_type.yield_to_scale(diff, config, state, metric, nil, logger){}}.to \
            change{state["downscale_sensitivity"]}.by(1)
        end

        it 'resets upscale sensitivity level' do
          expect{base_type.yield_to_scale(diff, config, state, metric, nil, logger){}}.to \
            change{state["upscale_sensitivity"]}.to(0)
        end

        context 'when reached required downscale sensitivity level' do
          let(:config) { {"downscale_sensitivity" => 3} }
          let(:state) { {"downscale_sensitivity" => 2} }

          it 'yields to scale' do
            expect{|b| base_type.yield_to_scale(diff, config, state, metric, nil, logger, &b)}.to \
              yield_control
          end

          it 'resets downscale sensitivity level' do
            expect{base_type.yield_to_scale(diff, config, state, metric, nil, logger){}}.to \
              change{state["downscale_sensitivity"]}.to(0)
          end
        end

        context 'when blocked by lower downscale sensitivity level' do
          let(:config) { {"downscale_sensitivity" => 3} }
          let(:state) { {"downscale_sensitivity" => 1} }

          it 'does not yield' do
            expect{|b| base_type.yield_to_scale(diff, config, state, metric, nil, logger, &b)}.not_to \
              yield_control
          end

          it 'logs a debug message' do
            expect(logger).to receive(:debug).with(/blocked by downscale_sensitivity/)
            base_type.yield_to_scale(diff, config, state, metric, nil, logger)
          end
        end
      end

      context 'when cannot scale down' do
        let(:state) { {"upscale_sensitivity" => 2, "downscale_sensitivity" => 3} }

        before {
          allow(base_type).to receive(:can_scale_down?).with(metric, config){ nil }
        }

        it 'does not change upscale_sensitivity level' do
          expect{base_type.yield_to_scale(diff, config, state, metric, nil, logger)}.not_to \
            change{state["upscale_sensitivity"]}
        end

        it 'does not change downscale_sensitivity level' do
          expect{base_type.yield_to_scale(diff, config, state, metric, nil, logger)}.not_to \
            change{state["downscale_sensitivity"]}
        end

        it 'logs a debug message' do
          expect(logger).to receive(:debug).with(/blocked by a non-decrementable/)
          base_type.yield_to_scale(diff, config, state, metric, nil, logger)
        end
      end
    end

    context 'when not scaling' do
      let(:diff) { 0 }
      let(:state) { {"upscale_sensitivity" => 2, "downscale_sensitivity" => 3} }

      it 'resets both sensitivity levels' do
        expect{base_type.yield_to_scale(diff, nil, state, nil, nil, logger)}.to \
          change{state["upscale_sensitivity"]}.to(0).and \
          change{state["downscale_sensitivity"]}.to(0)
      end

      it 'logs an info message' do
        expect(logger).to receive(:info).with(/No need to scale/)
        base_type.yield_to_scale(diff, nil, state, nil, nil, logger)
      end
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
