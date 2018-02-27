module Scaltainer
  class DockerService < ReplicaSetBase
    def initialize(service_name, stack_name)
      # set logger?
      full_name = stack_name ? "#{stack_name}_#{service_name}" : service_name
      @service = Docker::Service.all(filters: {name: [full_name]}.to_json)[0]
      raise "Docker Service not found: #{full_name}" unless @service
      @id = @service.id
      super(service_name, 'service', stack_name)
    end

    def get_replicas
      replicated = @service.info["Spec"]["Mode"]["Replicated"]
      raise ConfigurationError.new "Cannot replicate a global service: #{@name}" unless replicated
      replicated["Replicas"]
    end

    def set_replicas(replicas)
      @service.scale replicas
    end
  end
end

# source: https://github.com/Stazer/docker-api/blob/feature/swarm_support/lib/docker/service.rb

# This class represents a Docker Service. It's important to note that nothing
# is cached so that the information is always up to date.
require "docker"

class Docker::Service
  include Docker::Base

  def self.all(opts = {}, conn = Docker.connection)
    hashes = Docker::Util.parse_json(conn.get('/services', opts)) || []
    hashes.map { |hash| new(conn, hash) }
  end

  def update(opts)
    version = self.info["Version"]["Index"]
    connection.post("/services/#{self.id}/update", {version: version}, body: opts.to_json)
  end

  def scale(replicas)
    spec = self.info["Spec"]
    spec["Mode"]["Replicated"]["Replicas"] = replicas
    update(spec)
  end
  
  private_class_method :new
end
