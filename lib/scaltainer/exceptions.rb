module Scaltainer
  class ApplicationError < RuntimeError; end
  class ConfigurationError < ApplicationError; end
  class NetworkError < ApplicationError; end
  class Warning < ApplicationError; end

  # Raised when the orchestrator rejects our credentials (HTTP 401).
  #
  # Deliberately NOT a descendant of ApplicationError (and therefore not of
  # RuntimeError), so that it is *not* caught by the `rescue RuntimeError`
  # handlers in Runner#iterate_services that exist to skip one bad service and
  # keep looping. An expired credential is not recoverable by continuing the
  # loop: the process has to exit so the orchestrator restarts it and the
  # credential is read from disk again.
  class AuthenticationError < StandardError; end
end