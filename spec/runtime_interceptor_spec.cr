require "./spec_helper"

class RuntimeInterceptorConfig
  include CrConfig

  option myString : String
  option sub : RuntimeInterceptorSubConfig
end

class RuntimeInterceptorSubConfig
  include CrConfig

  option myInts : Array(Int32)
end

describe "Runtime Interceptors" do
  Spec.before_each do
    RuntimeInterceptorConfig.reset
  end

  it "provides a single interception" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", [3])
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      next "something else" if name == "myString"
    end

    r = RuntimeInterceptorConfig.load
    r.myString.should eq "something else"
    r.sub.myInts.should eq [3]
  end

  it "don't continue past returned one" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", [3])
    end

    count = 0
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      count += 1
      next nil
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      count += 1
      next val.as(Array(Int32)) + [1, 2, 3] if name == "sub.myInts"
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      count += 1
      next nil
    end

    r = RuntimeInterceptorConfig.load
    r.myString.should eq "my super string"
    r.sub.myInts.should eq [3, 1, 2, 3]
    count.should eq 5 # 2 props hit for first, 2 props for 2nd, 1 prop for the 3rd
  end

  it "can use next without providing nil" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      next unless name == "myString"

      next "something else"
    end

    r = RuntimeInterceptorConfig.instance
    r.myString.should eq "something else"
    r.sub.myInts.should eq [3]
  end

  it "can be configured at runtime" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    return_somethinge_else = false
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      next unless name == "myString"
      next "something else" if return_somethinge_else
    end

    r = RuntimeInterceptorConfig.instance
    r.myString.should eq "my super string"

    return_somethinge_else = true
    r.myString.should eq "something else"

    return_somethinge_else = false
    r.myString.should eq "my super string"
  end
end
