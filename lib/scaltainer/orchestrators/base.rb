module Scaltainer
  class ReplicaSetBase
    attr_accessor :id, :name, :type, :namespace

    def initialize(name, type, namespace = nil, replicas = 0)
      @name, @type, @namespace, @replicas = name, type, namespace, replicas
    end

    def get_replicas
      @replicas
    end

    def set_replicas(replicas)
      @replicas = replicas
    end
  end
end
