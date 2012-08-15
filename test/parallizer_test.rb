require 'helper'

class ParallizerTest < Test::Unit::TestCase
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
  
  context ".add" do
    setup do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @parallizer.add.a_method('arg')
    end
    
    should "add call to calls" do
      assert_equal [:a_method, 'arg'], @parallizer.calls.first
    end
  end
  
  context ".add_call" do
    setup do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @parallizer.add_call(@method, 'arg') rescue $!
    end
    
    context "with proxy already created" do
      setup do
        @parallizer.instance_variable_set(:@proxy, mock('proxy'))
      end
      
      should "raise ArgumentError" do
        assert_equal ArgumentError, @execute_result.class
      end
    end
    
    context "with string method name added" do
      setup do
        @method = 'a_method'
      end
      
      should "add call to calls" do
        assert_equal [:a_method, 'arg'], @parallizer.calls.first
      end
    end
    
    context "with symbol method name" do
      setup do
        @method = 'a_method'
      end
      
      should "add call to calls" do
        assert_equal [:a_method, 'arg'], @parallizer.calls.first
      end
    end
  end
  
  context ".create_proxy" do
    setup do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @proxy = @parallizer.create_proxy rescue $!
    end
    
    context "with existing method on client" do
      setup do
        @parallizer.add_call(:a_method, 'arg')
      end
      
      should "execute method with add_call in a separate thread" do
        assert_not_equal Thread.current, @proxy.a_method('arg')
      end
      
      should "execute method not added with add_call in current thread" do
        assert_equal Thread.current, @proxy.another_method
      end
    end
    
    context "with proxy already created" do
      setup do
        @parallizer.instance_variable_set(:@proxy, mock('proxy'))
      end
      
      should "raise ArgumentError" do
        assert_equal ArgumentError, @execute_result.class
      end
    end
  end
  
  context "with retries" do
    setup do
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
      setup do
        # NOTE: added reverse order
        @client.expects(@method).returns('success')
        @retries.times { @client.expects(@method).raises('an error') }
      end
      
      should "return successful method response" do
        assert_equal 'success', @execute_result
      end
    end
    
    
    context "with failures greater than retries" do
      setup do
        (@retries + 1).times { @client.expects(@method).raises('an error') }
      end
      
      should "return successful method response" do
        assert_equal 'an error', @execute_result.message
      end
    end
  end
end
