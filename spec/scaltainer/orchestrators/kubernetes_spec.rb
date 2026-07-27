require 'spec_helper'

describe Scaltainer::AuthenticationError do
  it 'is a StandardError' do
    expect(described_class.new('x')).to be_a StandardError
  end

  # This is the whole point of the class: Runner#iterate_services rescues
  # RuntimeError in order to skip a single misbehaving service and keep the
  # loop alive. An expired credential must NOT be skipped that way, so the
  # class must sit outside the RuntimeError branch of the hierarchy.
  it 'is not a RuntimeError, so the Runner loop handlers cannot swallow it' do
    expect(described_class.ancestors).not_to include(RuntimeError)
    expect(described_class.ancestors).not_to include(Scaltainer::ApplicationError)
  end
end

describe Scaltainer::KubeResource do
  describe '.get_client_from_serviceaccount' do
    let(:dir) { '/var/run/secrets/kubernetes.io/serviceaccount' }
    let(:captured) { {} }

    before do
      allow(described_class).to receive(:read_secret).with(dir, 'ca.crt').and_return('CA')
      allow(described_class).to receive(:read_secret).with(dir, 'namespace').and_return('rayyan-staging')
      allow(OpenSSL::X509::Certificate).to receive(:new).with('CA').and_return(:cert)
      allow(Kubeclient::Client).to receive(:new) { |*_a, **kw| captured.merge!(kw); :client }
    end

    # The whole point of the kubeclient >= 4.10 bump: handing over the path lets
    # kubeclient re-read the file per request, so a rotated token is picked up.
    # Handing over the contents freezes the token at process start.
    it 'passes the token file path, not the token contents' do
      described_class.get_client_from_serviceaccount(dir)

      expect(captured[:auth_options]).to eq(bearer_token_file: "#{dir}/token")
    end

    it 'never reads the token file itself' do
      described_class.get_client_from_serviceaccount(dir)

      expect(described_class).not_to have_received(:read_secret).with(dir, 'token')
    end
  end

  describe '.raising_authentication_errors' do
    it 'returns the block value when nothing is raised' do
      expect(described_class.raising_authentication_errors { :ok }).to eq :ok
    end

    it 'translates HTTP 401 into Scaltainer::AuthenticationError' do
      expect {
        described_class.raising_authentication_errors do
          raise Kubeclient::HttpError.new(401, 'Unauthorized', nil)
        end
      }.to raise_error(Scaltainer::AuthenticationError, /401 Unauthorized/)
    end

    it 'leaves HTTP 403 alone so RBAC problems do not crash-loop the pod' do
      expect {
        described_class.raising_authentication_errors do
          raise Kubeclient::HttpError.new(403, 'Forbidden', nil)
        end
      }.to raise_error(Kubeclient::HttpError)
    end

    it 'leaves HTTP 404 alone so a genuinely missing resource is still skipped' do
      expect {
        described_class.raising_authentication_errors do
          raise Kubeclient::ResourceNotFoundError.new(404, 'Not Found', nil)
        end
      }.to raise_error(Kubeclient::ResourceNotFoundError)
    end

    it 'leaves non-kubeclient errors alone' do
      expect {
        described_class.raising_authentication_errors { raise IOError, 'socket went away' }
      }.to raise_error(IOError)
    end
  end
end
