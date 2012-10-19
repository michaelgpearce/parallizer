require 'work_queue'
require 'parallizer/version'
require 'parallizer/proxy'
require 'parallizer/method_call_notifier'

class Parallizer
  WORK_QUEUE_SIZE = 10
  
  attr_reader :calls, :call_infos, :client, :proxy, :options
  
  def initialize(client, options = {})
    @client = client
    @options = {:retries => 0}.merge(options)
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
    return if call_infos[method_name_and_args]
    
    call_info = {
      :complete? => false,
      :result => nil,
      :exception => nil,
      :condition_variable => ConditionVariable.new,
      :mutex => Mutex.new,
      :retries => options[:retries]
    }
    call_infos[method_name_and_args] = call_info
    
    enqueue_call_info(call_info, method_name_and_args)
  end
  
  def create_proxy
    raise ArgumentError, "Cannot create another proxy" if @proxy
    
    Parallizer::Proxy.new(client, call_infos)
  end
  
  def self.work_queue
    @parallizer_work_queue ||= create_work_queue
  end
  
  def self.create_work_queue
    WorkQueue.new(WORK_QUEUE_SIZE)
  end
  
  private
  
  def enqueue_call_info(call_info, method_name_and_args)
    Parallizer.work_queue.enqueue_b do
      call_info[:mutex].synchronize do
        begin
          (call_info[:retries] + 1).times do
            begin
              call_info[:exception] = nil # reset exception before each send attempt
              call_info[:result] = client.send(*method_name_and_args)
              break # success
            rescue Exception => e
              call_info[:exception] = e
            end
          end
        ensure
          call_info[:complete?] = true
          call_info[:condition_variable].broadcast
        end
      end
    end
  end
end
