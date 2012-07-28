require 'test_helper'

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
    end
    
    context "with method that exists on client" do
      context "with method and arg in execute results" do
        setup do
          @method_result = "some value"
          @method_arg = "some arg"
          @execution_results = {[:a_method, @method_arg] => {:result => @method_result}}
        end

        should "return value from execution_results" do
          assert_equal @method_result, Parallizer::Proxy.new(@client, @execution_results).a_method(@method_arg)
        end

        context "with exception in execute results" do
          setup do
            @execution_results = {[:a_method, @method_arg] => {:exception => Exception.new("an exception")}}
          end
          
          should "raise exception" do
            assert_raises Exception, "an exception" do
              Parallizer::Proxy.new(@client, @execution_results).a_method(@method_arg)
            end
          end
        end
      end
      
      context "with method and arg not in execute result" do
        setup do
          @execution_results = {[:a_method, :unknown] => "unknown"}
        end

        should "return value from client object" do
          assert_equal DEFAULT_RETURN_VALUE, Parallizer::Proxy.new(@client, @execution_results).a_method(:not_unknown)
        end
      end
    end
    
    context "with method that does not exist on client" do
      setup do
        @execution_results = {[:a_method, @method_arg] => {:result => @method_result}}
      end
      
      should "raise exception" do
        assert_raises NoMethodError, "an exception" do
          Parallizer::Proxy.new(@client, @execution_results).unknown_method()
        end
      end
    end
  end
  
  context ".respond_to?" do
    setup do
      client = TestObject.new
      execution_results = {[:a_method, 'valid argument'] => {:result => 'valid result'}}
      @proxy = Parallizer::Proxy.new(client, execution_results)
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
