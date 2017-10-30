module Scaltainer
  class ApplicationError < RuntimeError; end
  class ConfigurationError < ApplicationError; end
  class Warning < ApplicationError; end
end