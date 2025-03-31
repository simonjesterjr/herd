require 'tsort'

module Herd
  class DependencyGraph < Hash
    include TSort

    def tsort_each_node(&block)
      each_key(&block)
    end

    def tsort_each_child(node, &block)
      fetch(node).each(&block)
    end
  end

end
