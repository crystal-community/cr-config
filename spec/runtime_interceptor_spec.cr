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

    return_something_else = false
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      next unless name == "myString"
      "test" # placed here to make sure that it's not returned when return_something_else is false
      next "something else" if return_something_else
    end

    r = RuntimeInterceptorConfig.instance
    r.myString.should eq "my super string"

    return_something_else = true
    r.myString.should eq "something else"

    return_something_else = false
    r.myString.should eq "my super string"
  end

  it "doesn't go through infinite loops" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    count = 0
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      if name == "myString"
        c = RuntimeInterceptorConfig.instance
        count += 1
        next c.myString # will trigger another lookup and interception of this variable
      end
    end

    r = RuntimeInterceptorConfig.instance

    count.should eq 0
    r.myString.should eq "my super string"
    count.should eq 1
  end

  it "allows interceptors to be triggered once per property" do
    RuntimeInterceptorConfig.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    count = 0
    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      if name == "sub.myInts"
        c = RuntimeInterceptorConfig.instance
        count += 1
        c.myString # will trigger another lookup and interception of this variable
        next c.sub.myInts
      end
    end

    RuntimeInterceptorConfig.runtime_interceptor do |name, val|
      if name == "myString"
        c = RuntimeInterceptorConfig.instance
        count += 1
        c.sub.myInts
        next c.myString
      end
    end

    r = RuntimeInterceptorConfig.instance

    count.should eq 0
    r.sub.myInts.should eq [3]
    count.should eq 2 # 1 for the myString interceptor, 1 for the myInts interceptor
  end
end
