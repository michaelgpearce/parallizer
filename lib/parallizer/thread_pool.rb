require 'thread'

class Parallizer
  # Initially taken from Celluloid. -mgp
  module ThreadPool
    THEAD_POOL_SIZE = 16
    
    @pool = []
    @mutex = Mutex.new

    @max_idle = THEAD_POOL_SIZE

    class << self
      attr_accessor :max_idle

      # Get a thread from the pool, running the given block
      def get(&block)
        @mutex.synchronize do
          begin
            if @pool.empty?
              thread = create
            else
              thread = @pool.shift
            end
          end until thread.status # handle crashed threads

          thread[:queue] << block
          thread
        end
      end

      # Return a thread to the pool
      def put(thread)
        @mutex.synchronize do
          if @pool.size >= @max_idle
            thread[:queue] << nil
          else
            @pool << thread
          end
        end
      end

      # Create a new thread with an associated queue of procs to run
      def create
        queue = Queue.new
        thread = Thread.new do
          while proc = queue.pop
            begin
              proc.call
            rescue => ex
              # Let this thread die on exceptions other than standard errors
            end
            put thread
          end
        end

        thread[:queue] = queue
        thread
      end
    end
  end
end

