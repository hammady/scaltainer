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
