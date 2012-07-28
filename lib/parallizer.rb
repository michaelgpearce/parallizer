require 'set'
require 'work_queue'
require 'parallizer/proxy'
require 'parallizer/method_call_notifier'

class Parallizer
  attr_accessor :calls, :client
  
  def initialize(client)
    self.client = client
    self.calls = Set.new
  end
  
  def add
    MethodCallNotifier.new do |*args|
      self.calls.add(args)
    end
  end
  
  def add_call(method_name, *args)
    calls.add([method_name.to_sym, *args])
  end
  
  def execute
    Parallizer.execute_all(self).first
  end
  
  def self.work_queue
    # TODO: share the work queue among calling threads
    Thread.current[:parallizer_work_queue] ||= WorkQueue.new(10)
  end
  
  def self.execute_all(*parallizers)
    parallizers_execution_results = {}
    parallizers.each do |parallizer|
      execution_results = {}
      parallizers_execution_results[parallizer] = execution_results
      
      parallizer.calls.each do |name_and_args|
        Parallizer.work_queue.enqueue_b do
          begin
            execution_results[name_and_args] = {:result => parallizer.client.send(*name_and_args)}
          rescue Exception => e
            execution_results[name_and_args] = {:exception => e}
          end
        end
      end
    end
    
    Parallizer.work_queue.join

    return parallizers_execution_results.collect do |parallizer, execution_results|
      Parallizer::Proxy.new(parallizer.client, execution_results)
    end
  end
end
