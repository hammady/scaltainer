module Scaltainer
  # Recoverable conditions. The runner logs these and skips the affected
  # resource (or resource type) for the current tick, then carries on.
  class ApplicationError < RuntimeError; end
  class NetworkError < ApplicationError; end
  class Warning < ApplicationError; end

  # Permanent misconfiguration. Retrying cannot fix it, so it is left to bubble
  # up and terminate the process instead of being logged on every tick.
  class ConfigurationError < RuntimeError; end
end
