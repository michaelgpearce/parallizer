require 'celluloid'
Celluloid.logger = nil
require 'parallizer/version'
require 'parallizer/proxy'
require 'parallizer/worker'
require 'parallizer/method_call_notifier'

class Parallizer
  DEFAULT_WORK_QUEUE_SIZE = 10
  
  class << self
    def work_queue_size
      @work_queue_size || DEFAULT_WORK_QUEUE_SIZE
    end
    
    def work_queue_size=(work_queue_size)
      @work_queue_size = work_queue_size
    end
    
    def work_queue
      # TODO: share the work queue among calling threads??
      queue = Thread.current[:parallizer_work_queue]
      if queue.nil? || Thread.current[:parallizer_work_queue_size] != work_queue_size
        queue = Thread.current[:parallizer_work_queue] = ::Parallizer::Worker.pool(:size => work_queue_size)
        Thread.current[:parallizer_work_queue_size] = work_queue_size
      end
      
      queue
    end
  end
  
  attr_reader :calls, :call_infos, :client, :proxy, :options

  def initialize(client, options = {})
    @client = client
    @options = {:retries => 0}.merge(options)
    @call_infos = {}
  end

  def add
    ::Parallizer::MethodCallNotifier.new do |*args|
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
      :future => ::Parallizer::work_queue.future(:run, @client, method_name, args, options),
      :result => nil,
      :exception => nil
    }
    call_infos[method_name_and_args] = call_info
  end

  def create_proxy
    raise ArgumentError, "Cannot create another proxy" if @proxy

    execute

    ::Parallizer::Proxy.new(client, call_infos)
  end

  def all_call_results
    proxy = create_proxy

    call_infos.keys.inject({}) do |result, method_name_and_args|
      result[method_name_and_args] = proxy.send(*method_name_and_args)

      result
    end
  end

  private

  def execute
    call_infos.each do |method_name_and_args, call_info|
      call_info.merge!(call_info[:future].value)
    end

    ::Parallizer::Proxy.new(client, call_infos)
  end
end
