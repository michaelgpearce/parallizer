require 'thread'
require 'set'

class Parallizer
  class Proxy
    def initialize(client, call_infos)
      @client = client
      @call_infos = call_infos
    end

    def method_missing(name, *args, &block)
      if call_info = @call_infos[[name, *args]]
        if call_info[:exception]
          # add the current call stack to the exception backtrace
          exception = call_info[:exception].clone
          exception.set_backtrace((call_info[:exception].backtrace || []) + caller)
          raise exception
        else
          call_info[:result]
        end
      else
        @client.send(*[name, *args], &block)
      end
    end
  
    def respond_to?(name, include_private = false, &block)
      @execution_methods ||= Set.new(@call_infos.keys.collect(&:first))
    
      if @execution_methods.include?(name.to_sym)
        true
      else
        super
      end
    end
  end
end
