require 'spec_helper'

describe Parallizer::MethodCallNotifier do
  describe "#method_missing" do
    before do
      @notifier = Parallizer::MethodCallNotifier.new do |*args|
        @callback_args = args
      end
    end
    
    execute do
      @method_call_result = @notifier.call_a_method('with args')
    end
    
    it "should call block on method call" do
      @callback_args.should == [:call_a_method, 'with args']
    end
    
    it "should return the notifier" do
      @method_call_result.should == @notifier
    end
  end
end