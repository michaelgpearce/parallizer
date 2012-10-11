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
  
  context "with multiple threads making calls to proxy before worker executed" do
    it "should not deadlock" do # note, this was deadlocking when using CV#signal instead of CV#broadcast
      # force our worker thread to run after two calls from other threads
      Parallizer::WORK_QUEUE_SIZE.times do
        Parallizer.work_queue.enqueue_b do
          sleep(2)
        end
      end

      # setup the proxy
      parallizer = Parallizer.new(TestObject.new)
      parallizer.add.another_method
      proxy = parallizer.create_proxy

      Thread.new do
        proxy.another_method # call in another thread must happen before call in main thread for it to deadlock
      end
      sleep(1)
      proxy.another_method
    end
  end
end
