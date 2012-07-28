require 'set'

class Parallizer
  class Proxy
    def initialize(client, execution_results)
      @client = client
      @execution_results = execution_results
    end

    def method_missing(name, *args, &block)
      if @execution_results.key?([name, *args])
        value = @execution_results[[name, *args]]
        if value[:exception]
          raise value[:exception]
        else
          value[:result]
        end
      else
        @client.send(*[name, *args], &block)
      end
    end
  
    def respond_to?(name, include_private = false, &block)
      @execution_methods ||= Set.new(@execution_results.keys.collect(&:first))
    
      if @execution_methods.include?(name.to_sym)
        true
      else
        super
      end
    end
  end
end
