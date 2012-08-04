require 'thread'
require 'set'

class Parallizer
  class Proxy
    def initialize(client, call_infos)
      @client = client
      @call_infos = call_infos
    end

    def method_missing(name, *args, &block)
      value = nil
      
      if call_info = @call_infos[[name, *args]]
        call_info[:mutex].synchronize do
          if !call_info[:complete?]
            # not done, so lets wait for signal of completion
            call_info[:condition_variable].wait(call_info[:mutex])
          end
          # we now have our result from the worker thread
          
          raise call_info[:exception] if call_info[:exception]
          
          value = call_info[:result]
        end
      else
        # pass through to client since not added
        value = @client.send(*[name, *args], &block)
      end
      
      value
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
