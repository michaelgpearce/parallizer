require 'spec_helper'

describe Parallizer::Proxy do
  DEFAULT_RETURN_VALUE = "return value"
  
  class TestObject
    def a_method(arg)
      DEFAULT_RETURN_VALUE
    end
  end
  
  describe "#method_missing" do
    before do
      @client = TestObject.new
      @call_key = []
      @call_info = {:result => nil, :exception => nil, :complete? => true,
        :condition_variable => ConditionVariable.new, :mutex => Mutex.new }
    end
    
    execute do
      call_infos = { @call_key => @call_info }
      proxy = Parallizer::Proxy.new(@client, call_infos)
      proxy.send(*@call_key) rescue $!
    end
    
    context "with method that exists on client" do
      context "with method and arg call info" do
        before do
          @call_key += [:a_method, "some value"]
        end
        
        context "with an exception" do
          before do
            @call_info[:exception] = StandardError.new('An Exception')
            @call_info[:exception].set_backtrace(["/tmp/foo.rb:123:in `in a_worker_thread_method'"])
          end
          
          execute do
            def a_calling_thread_method
              call_infos = { @call_key => @call_info }
              proxy = Parallizer::Proxy.new(@client, call_infos)
              proxy.send(*@call_key) rescue $!
            end
            a_calling_thread_method
          end

          it "should raise exception" do
            @execute_result.class.should == @call_info[:exception].class
            @execute_result.message.should == @call_info[:exception].message
          end
          
          it "should append backtrace of current call" do
            @execute_result.backtrace.join.should match /a_worker_thread_method/
            @execute_result.backtrace.join.should match /a_calling_thread_method/
          end
        end
        
        context "with a result" do
          before do
            @call_info[:result] = "a result"
          end
          
          it "should return result" do
            @execute_result.should == @call_info[:result]
          end
        end
      end
      
      context "with no method and arg not in execute result" do
        before do
          @call_key += [:a_method, "some parameter"]
          @call_info = nil
        end
        
        it "should return value from client object" do
          @execute_result.should == DEFAULT_RETURN_VALUE
        end
      end
    end
    
    context "with method that does not exist on client" do
      before do
        @call_key += [:unknown_method, "some parameter"]
        @call_info = nil
      end
      
      it "should raise exception" do
        @execute_result.class.should == NoMethodError
      end
    end
  end
  
  describe "#respond_to?" do
    before do
      client = TestObject.new
      call_key = [:a_method, 'valid argument']
      call_info = {:result => nil, :exception => nil, :complete? => true,
        :condition_variable => ConditionVariable.new, :mutex => Mutex.new }
      @proxy = Parallizer::Proxy.new(client, { call_key => call_info })
    end
    
    it "should respond to proxy method as symbol" do
      @proxy.should respond_to(:a_method)
    end
    
    it "should respond to proxy method as string" do
      @proxy.should respond_to('a_method')
    end
    
    it "should respond to methods inherited from object" do
      @proxy.should respond_to(:to_s)
    end
    
    it "should not respond to methods that do not exist" do
      @proxy.should_not respond_to(:invalid_method)
    end
  end
  
end
