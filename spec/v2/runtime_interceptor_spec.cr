require "../spec_helper"

class RuntimeInterceptorConfig
  include CrCfgV2

  option myString : String
end

describe "Runtime Interceptors" do
  Spec.before_each do
    RuntimeInterceptorConfig.reset
  end

  it "provides a single interception" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      next "something else" if name == "myString"
    end

    r = RuntimeInterceptorConfig.load
    r.myString.should eq "something else"
  end

  it "don't continue past returned one" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
    end

    count = 0
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      count += 1
      next nil
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      count += 1
      next "#{val} string"
    end

    # This interceptor won't be run, because above one returns a non-nil value
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      count += 1
      next nil
    end

    r = RuntimeInterceptorConfig.load
    r.myString.should eq "my super string string"
    count.should eq 2
  end
end
