class Parallizer
  class Worker
    include Celluloid
    
    def run(client, method_name, args, options)
      result = {}
      
      (options[:retries] + 1).times do
        begin
          Thread.current[:parallizer_thread] = true

          result[:exception] = nil # reset exception before each send attempt
          result[:result] = client.send(method_name, *args)
          break # success
        rescue Exception => e
          result[:exception] = e
        ensure
          Thread.current[:parallizer_thread] = nil
        end
      end

      result
    end
  end
end

