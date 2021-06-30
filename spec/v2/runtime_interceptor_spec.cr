require "../spec_helper"

class RuntimeInterceptorConfig
  include CrCfgV2

  option myString : String
  option sub : RuntimeInterceptorSubConfig
end

class RuntimeInterceptorSubConfig
  include CrCfgV2

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
end
