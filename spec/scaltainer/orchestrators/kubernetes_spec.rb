require 'spec_helper'

include Scaltainer

describe KubeResource do
  let(:client) { double('Kubeclient::Client') }
  let(:metadata) { double('metadata', uid: 'uid-1') }
  let(:resource) { double('resource', metadata: metadata) }
  let(:kube_resource) { KubeResource.new('web_app', 'ns') }

  before {
    KubeResource.class_variable_set(:@@client, client)
    allow(client).to receive(:send).with('get_deployment', 'web-app', 'ns').and_return(resource)
  }

  after {
    KubeResource.remove_class_variable(:@@client)
  }

  describe '.new' do
    def stub_get_error(code)
      allow(client).to receive(:send)
        .with('get_deployment', 'web-app', 'ns')
        .and_raise(Kubeclient::HttpError.new(code, 'boom', nil))
    end

    context 'when the resource is not in the cluster' do
      before { stub_get_error(404) }

      it 'raises Warning so the resource is skipped for this tick' do
        expect{kube_resource}.to \
          raise_exception Scaltainer::Warning, /Could not find deployment web_app in namespace ns/
      end
    end

    context 'when the credentials are rejected' do
      before { stub_get_error(401) }

      it 'raises ConfigurationError' do
        expect{kube_resource}.to raise_exception ConfigurationError, /Could not find/
      end
    end

    context 'when the credentials lack permission' do
      before { stub_get_error(403) }

      it 'raises ConfigurationError' do
        expect{kube_resource}.to raise_exception ConfigurationError, /Could not find/
      end
    end

    context 'when the api server errors' do
      before { stub_get_error(500) }

      it 'raises NetworkError' do
        expect{kube_resource}.to raise_exception NetworkError, /Could not find/
      end
    end

    context 'when the resource is found' do
      it 'exposes the resource id' do
        expect(kube_resource.id).to eq 'uid-1'
      end
    end
  end # describe .new

  describe '#set_replicas' do
    def stub_patch_error(code)
      allow(client).to receive(:send)
        .with('patch_deployment', 'web-app', {spec: {replicas: 3}}, 'ns')
        .and_raise(Kubeclient::HttpError.new(code, 'boom', nil))
    end

    context 'when the resource was modified concurrently' do
      before { stub_patch_error(409) }

      it 'raises Warning so the resource is retried on the next tick' do
        expect{kube_resource.set_replicas(3)}.to \
          raise_exception Scaltainer::Warning, /Could not scale deployment web_app in namespace ns/
      end
    end

    context 'when the resource is gone' do
      before { stub_patch_error(404) }

      it 'raises Warning so the resource is retried on the next tick' do
        expect{kube_resource.set_replicas(3)}.to \
          raise_exception Scaltainer::Warning, /Could not scale/
      end
    end

    context 'when the credentials are rejected' do
      before { stub_patch_error(401) }

      it 'raises ConfigurationError' do
        expect{kube_resource.set_replicas(3)}.to \
          raise_exception ConfigurationError, /Could not scale/
      end
    end

    context 'when the credentials lack permission' do
      before { stub_patch_error(403) }

      it 'raises ConfigurationError' do
        expect{kube_resource.set_replicas(3)}.to \
          raise_exception ConfigurationError, /Could not scale/
      end
    end

    context 'when the api server errors' do
      before { stub_patch_error(500) }

      it 'raises NetworkError' do
        expect{kube_resource.set_replicas(3)}.to \
          raise_exception NetworkError, /Could not scale/
      end
    end

    context 'when the patch succeeds' do
      before {
        allow(client).to receive(:send)
          .with('patch_deployment', 'web-app', {spec: {replicas: 3}}, 'ns')
          .and_return(resource)
      }

      it 'does not raise' do
        expect{kube_resource.set_replicas(3)}.to_not raise_exception
      end
    end
  end # describe #set_replicas
end # describe KubeResource
