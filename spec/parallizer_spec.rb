require 'spec_helper'

describe Parallizer do
  class TestObject
    def a_method(arg)
      Thread.current
    end
    
    def another_method
      Thread.current
    end
  end
  
  class AnotherTestObject
    def a_method
      Thread.current
    end
    
    def another_method
      Thread.current
    end
  end
  
  describe "#add" do
    before do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @parallizer.add.a_method('arg')
    end
    
    it "should add call to calls" do
      @parallizer.calls.first.should == [:a_method, 'arg']
    end
  end
  
  describe "#add_call" do
    before do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @parallizer.add_call(@method, 'arg') rescue $!
    end
    
    context "with proxy already created" do
      before do
        @parallizer.instance_variable_set(:@proxy, stub('a client'))
      end
      
      it "should raise ArgumentError" do
        @execute_result.class.should == ArgumentError
      end
    end
    
    context "with call already added" do
      before do
        @method = :a_method
        @parallizer.add_call(@method, 'arg')
        @call_info = @parallizer.call_infos[[@method, 'arg']]
        @call_info.should_not be_nil
      end
      
      it "should ignore additional call" do
        @call_info.object_id.should == @parallizer.call_infos[[@method, 'arg']].object_id
      end
    end
    
    context "with string method name added" do
      before do
        @method = 'a_method'
      end
      
      it "should add call to calls" do
        @parallizer.calls.first.should == [:a_method, 'arg']
      end
    end
    
    context "with symbol method name" do
      before do
        @method = 'a_method'
      end
      
      it "should add call to calls" do
        @parallizer.calls.first.should == [:a_method, 'arg']
      end
    end
  end
  
  describe "#create_proxy" do
    before do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @proxy = @parallizer.create_proxy rescue $!
    end
    
    context "with existing method on client" do
      before do
        @parallizer.add_call(:a_method, 'arg')
      end
      
      it "should execute method with add_call in a separate thread" do
        @proxy.a_method('arg').should_not == Thread.current
      end
      
      it "should execute method not added with add_call in current thread" do
        @proxy.another_method.should == Thread.current
      end
    end
    
    context "with proxy already created" do
      before do
        @parallizer.instance_variable_set(:@proxy, stub('a client'))
      end
      
      it "should raise ArgumentError" do
        @execute_result.class.should == ArgumentError
      end
    end
  end
  
  context "with retries" do
    before do
      @retries = 3
      @client = stub('a client')
      @method = :a_sometimes_failing_method
    end
    
    execute do
      parallizer = Parallizer.new(@client, :retries => @retries)
      parallizer.add_call(@method)
      proxy = parallizer.create_proxy
      proxy.send(@method) rescue $!
    end
    
    context "with success on last retry" do
      before do
        @client.should_receive(@method).exactly(@retries).times.and_raise('an error')
        @client.should_receive(@method).and_return('success')
      end
      
      it "should return successful method response" do
        @execute_result.should == 'success'
      end
    end
    
    
    context "with failures greater than retries" do
      before do
        (@retries + 1).times { @client.should_receive(@method).and_raise('an error') }
      end
      
      it "should return successful method response" do
        @execute_result.message.should == 'an error'
      end
    end
  end
  
  context "with exceptions that are not standard errors" do
    before do
      @retries = 3
      @client = stub('a client')
      @method = :a_failing_method
      (@retries + 1).times { @client.should_receive(@method).and_raise(Exception.new('an error')) }
    end
    
    execute do
      parallizer = Parallizer.new(@client, :retries => @retries)
      parallizer.add_call(@method)
      proxy = parallizer.create_proxy
      begin
        proxy.send(@method)
      rescue Exception
        $!
      end
    end
    
    it "should return successful method response" do
      @execute_result.message.should == 'an error'
    end
  end
  
  describe "#work_queue_size" do
    it "should be the default size when not specified" do
      Parallizer.work_queue_size.should == Parallizer::DEFAULT_WORK_QUEUE_SIZE
    end
    
    it "should have max threads equal to specified size after requesting the work queue" do
      size = rand(2..5)
      Parallizer.work_queue_size = size
      Parallizer.work_queue
      Thread.current[:parallizer_work_queue_size].should == size
    end
  end

  ## Unable to repro after switch to using ThreadPool instead of work_queue gem
  # context "with multiple threads making calls to proxy before worker executed" do
  #   it "should not deadlock" do # note, this was deadlocking when using CV#signal instead of CV#broadcast
  #     Parallizer::WORK_QUEUE_SIZE.times do
  #       Parallizer::ThreadPool.get do
  #         sleep(2)
  #       end
  #     end
  # 
  #     # setup the proxy
  #     parallizer = Parallizer.new(TestObject.new)
  #     parallizer.add.another_method
  #     proxy = parallizer.create_proxy
  # 
  #     Thread.new do
  #       proxy.another_method # call in another thread must happen before call in main thread for it to deadlock
  #     end
  #     sleep(1)
  #     proxy.another_method
  #   end
  # end
end
