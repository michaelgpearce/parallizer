require 'test_helper'

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
      @parallizer.add_call(@method, 'arg')
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
  
  context ".execute" do
    setup do
      @client = TestObject.new
      @parallizer = Parallizer.new(@client)
    end
    
    execute do
      @proxy = @parallizer.execute
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
  end
  
  context ".execute_all" do
    setup do
      @client1 = TestObject.new
      @parallizer1 = Parallizer.new(@client1)
      @parallizer1.add_call(:a_method, 'arg')
      @client2 = AnotherTestObject.new
      @parallizer2 = Parallizer.new(@client2)
      @parallizer2.add_call(:a_method)
    end

    execute do
      @proxy1, @proxy2 = Parallizer.execute_all(@parallizer1, @parallizer2)
    end

    should "execute methods with add_call in a separate thread" do
      assert_not_equal Thread.current, @proxy1.a_method('arg')
      assert_not_equal Thread.current, @proxy2.a_method
    end

    should "execute methods not added with add_call in current thread" do
      assert_equal Thread.current, @proxy1.another_method
      assert_equal Thread.current, @proxy2.another_method
    end
  end
end
