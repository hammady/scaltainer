require 'spec_helper'

include Scaltainer

describe 'exceptions' do
  # The runner rescues ApplicationError to skip a resource (or resource type)
  # and carry on to the next tick. What is and is not an ApplicationError is
  # therefore the difference between being retried forever and being fatal.

  describe 'recoverable errors' do
    it 'includes NetworkError' do
      expect(NetworkError.new).to be_a ApplicationError
    end

    it 'includes Warning' do
      expect(Scaltainer::Warning.new).to be_a ApplicationError
    end
  end

  describe 'permanent errors' do
    it 'does not include ConfigurationError' do
      expect(ConfigurationError.new).to_not be_a ApplicationError
    end

    it 'still makes ConfigurationError rescuable as a StandardError' do
      expect(ConfigurationError.new).to be_a StandardError
    end
  end
end
