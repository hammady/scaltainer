module Scaltainer
  class ReplicaSetBase
    attr_accessor :id, :name, :type, :namespace

    def initialize(name, type, namespace)
      @name, @type, @namespace = name, type, namespace
    end

    def get_replicas
      raise 'Abstract method, please override'
    end

    def set_replicas(replicas)
      raise 'Abstract method, please override'
    end
  end
end
