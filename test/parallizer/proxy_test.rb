require 'helper'

class Parallizer::ProxyTest < Test::Unit::TestCase
  DEFAULT_RETURN_VALUE = "return value"
  
  class TestObject
    def a_method(arg)
      DEFAULT_RETURN_VALUE
    end
  end
  
  context ".method_missing" do
    setup do
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
        setup do
          @call_key += [:a_method, "some value"]
        end
        
        context "with not complete?" do
          setup do
            @call_info[:complete?] = false
            @call_info[:condition_variable].expects(:wait).with(@call_info[:mutex])
            @call_info[:result] = 'this is a value'
          end
          
          should do
            assert_equal @call_info[:result], @execute_result
          end
        end
        
        context "with complete? call info" do
          setup do
            @call_info[:complete?] = true
          end
          
          context "with an exception" do
            setup do
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

            should "raise exception" do
              assert_equal @call_info[:exception].class, @execute_result.class
              assert_equal @call_info[:exception].message, @execute_result.message
            end
            
            should "append backtrace of current call" do
              assert @execute_result.backtrace.grep /a_worker_thread_method/
              assert @execute_result.backtrace.grep /a_calling_thread_method/
            end
          end
          
          context "with a result" do
            setup do
              @call_info[:result] = "a result"
            end
            
            should "return result" do
              assert_equal @call_info[:result], @execute_result
            end
          end
        end
      end
      
      context "with no method and arg not in execute result" do
        setup do
          @call_key += [:a_method, "some parameter"]
          @call_info = nil
        end
        
        should "return value from client object" do
          assert_equal DEFAULT_RETURN_VALUE, @execute_result
        end
      end
    end
    
    context "with method that does not exist on client" do
      setup do
        @call_key += [:unknown_method, "some parameter"]
        @call_info = nil
      end
      
      should "raise exception" do
        assert_equal NoMethodError, @execute_result.class
      end
    end
  end
  
  context ".respond_to?" do
    setup do
      client = TestObject.new
      call_key = [:a_method, 'valid argument']
      call_info = {:result => nil, :exception => nil, :complete? => true,
        :condition_variable => ConditionVariable.new, :mutex => Mutex.new }
      @proxy = Parallizer::Proxy.new(client, { call_key => call_info })
    end
    
    should "respond to proxy method as symbol" do
      assert @proxy.respond_to?(:a_method)
    end
    
    should "respond to proxy method as string" do
      assert @proxy.respond_to?('a_method')
    end
    
    should "respond to methods inherited from object" do
      assert @proxy.respond_to?(:to_s)
    end
    
    should "not respond to methods that do not exist" do
      assert !@proxy.respond_to?(:invalid_method)
    end
  end
  
end
