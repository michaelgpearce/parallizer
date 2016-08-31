require 'celluloid/current'
Celluloid.logger = nil
require 'hanging_methods'
require 'parallizer/version'
require 'parallizer/proxy'
require 'parallizer/worker'

class Parallizer
  include HangingMethods
  DEFAULT_WORK_QUEUE_SIZE = 10
  
  add_hanging_method :add, :after_invocation => :add_invoked
  
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

    def in_parallizer_thread?
      Thread.current[:parallizer_thread] == true
    end
  end
  
  attr_reader :calls, :call_infos, :client, :proxy, :options

  def initialize(client, options = {})
    @client = client
    @options = {:retries => 0}.merge(options)
    @call_infos = {}
  end

  def calls
    @call_infos.keys
  end

  def add_call(method_name, *args)
    add.send(method_name, *args)
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
  
  def add_invoked(method_name_and_args)
    raise ArgumentError, "Cannot add calls after proxy has been generated" if @proxy
  
    return if call_infos[method_name_and_args]
  
    call_info = {
      :future => ::Parallizer::work_queue.future(:run, @client, method_name_and_args.first, method_name_and_args[1..-1], options),
      :result => nil,
      :exception => nil
    }
    call_infos[method_name_and_args] = call_info
  end

  def execute
    call_infos.each do |method_name_and_args, call_info|
      call_info.merge!(call_info[:future].value)
    end
  end
end
