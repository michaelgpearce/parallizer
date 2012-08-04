require 'work_queue'
require 'parallizer/proxy'
require 'parallizer/method_call_notifier'

class Parallizer
  attr_reader :calls, :call_infos, :client, :proxy
  
  def initialize(client)
    @client = client
    @call_infos = {}
  end
  
  def add
    MethodCallNotifier.new do |*args|
      add_call(*args)
    end
  end
  
  def calls
    @call_infos.keys
  end
  
  def add_call(method_name, *args)
    raise ArgumentError, "Cannot add calls after proxy has been generated" if @proxy
    
    method_name_and_args = [method_name.to_sym, *args]
    
    call_info = {
      :complete? => false,
      :result => nil,
      :exception => nil,
      :condition_variable => ConditionVariable.new,
      :mutex => Mutex.new
    }
    call_infos[method_name_and_args] = call_info
    
    Parallizer.work_queue.enqueue_b do
      call_info[:mutex].synchronize do
        begin
          call_info[:result] = client.send(*method_name_and_args)
        rescue Exception => e
          call_info[:exception] = e
        ensure
          call_info[:complete?] = true
          call_info[:condition_variable].signal
        end
      end
    end
  end
  
  def create_proxy
    raise ArgumentError, "Cannot create another proxy" if @proxy
    
    Parallizer::Proxy.new(client, call_infos)
  end
  
  def self.work_queue
    @parallizer_work_queue ||= WorkQueue.new(10)
  end
end
