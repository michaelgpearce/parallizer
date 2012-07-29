require 'test_helper'

class Parallizer::MethodCallNotifierTest < Test::Unit::TestCase
  context ".method_missing" do
    setup do
      @notifier = Parallizer::MethodCallNotifier.new do |*args|
        @callback_args = args
      end
    end
    
    execute do
      @method_call_result = @notifier.call_a_method('with args')
    end
    
    should "call block on method call" do
      assert_equal [:call_a_method, 'with args'], @callback_args
    end
    
    should "return the notifier" do
      assert_equal @notifier, @method_call_result
    end
  end
end