require 'spec_helper'

describe Scaltainer::Runner do
  # Runner#initialize does a lot of I/O, and everything under test here is
  # private behaviour reachable without it, so allocate a bare instance and set
  # only the ivars the methods actually touch.
  let(:runner) { described_class.allocate }
  let(:logger) { Logger.new(File::NULL) }

  before do
    runner.instance_variable_set(:@logger, logger)
    runner.instance_variable_set(:@orchestrator, :kubernetes)
    runner.instance_variable_set(:@default_service_config, {})
  end

  describe '#get_service' do
    it 'lets AuthenticationError through instead of relabelling it as NetworkError' do
      allow(Scaltainer::KubeResource).to receive(:new)
        .and_raise(Scaltainer::AuthenticationError.new('token expired'))

      expect { runner.send(:get_service, 'customizer_by_filter', 'rayyan-staging') }
        .to raise_error(Scaltainer::AuthenticationError, /token expired/)
    end

    it 'still wraps every other failure as NetworkError' do
      allow(Scaltainer::KubeResource).to receive(:new).and_raise(IOError.new('boom'))

      expect { runner.send(:get_service, 'customizer_by_filter', 'rayyan-staging') }
        .to raise_error(Scaltainer::NetworkError, /Could not find resource with name/)
    end
  end

  describe '#scale_out' do
    let(:service) { double('service', type: 'deployment', name: 'customizer-by-filter') }

    it 'lets AuthenticationError through' do
      allow(service).to receive(:set_replicas)
        .and_raise(Scaltainer::AuthenticationError.new('token expired'))

      expect { runner.send(:scale_out, service, 1, 2) }
        .to raise_error(Scaltainer::AuthenticationError)
    end

    it 'still wraps every other failure as NetworkError' do
      allow(service).to receive(:set_replicas).and_raise(IOError.new('boom'))

      expect { runner.send(:scale_out, service, 1, 2) }
        .to raise_error(Scaltainer::NetworkError, /Could not scale/)
    end
  end

  describe '#iterate_services' do
    let(:type) { double('service_type', get_metrics: {}, to_s: 'web') }
    let(:services) { {'customizer_by_filter' => {}} }

    it 'propagates AuthenticationError out of the per-service loop' do
      allow(Scaltainer::KubeResource).to receive(:new)
        .and_raise(Scaltainer::AuthenticationError.new('token expired'))

      expect { runner.send(:iterate_services, services, 'rayyan-staging', type, {}) }
        .to raise_error(Scaltainer::AuthenticationError)
    end

    it 'keeps swallowing ordinary errors so one bad service does not stop the rest' do
      allow(Scaltainer::KubeResource).to receive(:new).and_raise(IOError.new('boom'))

      expect { runner.send(:iterate_services, services, 'rayyan-staging', type, {}) }
        .not_to raise_error
    end
  end
end
