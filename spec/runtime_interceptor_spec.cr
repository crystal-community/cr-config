require "./spec_helper"

class RuntimeInterceptorConfig
  include CrConfig

  option myBool : Bool, default: true
  option myString : String
  option myNilString : String?
  option sub : RuntimeInterceptorSubConfig
end

class RuntimeInterceptorSubConfig
  include CrConfig

  option myInts : Array(Int32)
end

describe "Runtime Interceptors" do
  it "provides a single interception" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", [3])
    end.runtime_interceptor do |name, val|
      next "something else" if name == "myString"
    end

    r = builder.build
    r.myString.should eq "something else"
    r.sub.myInts.should eq [3]
    r.myBool?.should be_true
  end

  it "don't continue past returned one" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", [3])
    end

    count = 0
    builder.runtime_interceptor do |name, val|
      count += 1
      next nil
    end

    builder.runtime_interceptor do |name, val|
      count += 1
      next val.as(Array(Int32)) + [1, 2, 3] if name == "sub.myInts"
    end

    builder.runtime_interceptor do |name, val|
      count += 1
      next nil
    end

    r = builder.build
    r.myString.should eq "my super string"
    r.sub.myInts.should eq [3, 1, 2, 3]
    count.should eq 5 # 2 props hit for first, 2 props for 2nd, 1 prop for the 3rd
  end

  it "can use next without providing nil" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    builder.runtime_interceptor do |name, val|
      next unless name == "myString"

      next "something else"
    end

    r = builder.build
    r.myString.should eq "something else"
    r.sub.myInts.should eq [3]
  end

  it "can be configured at runtime" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    return_something_else = false
    builder.runtime_interceptor do |name, val|
      next unless name == "myString"
      "test" # placed here to make sure that it's not returned when return_something_else is false
      next "something else" if return_something_else
    end

    r = builder.build
    r.myString.should eq "my super string"

    return_something_else = true
    r.myString.should eq "something else"

    return_something_else = false
    r.myString.should eq "my super string"
  end

  it "supports intercepting nilable values" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    return_something_else = false
    builder.runtime_interceptor do |name, val|
      next unless name == "myNilString"
      "no longer nil"
    end

    r = builder.build
    r.myNilString.should eq "no longer nil"
  end

  it "doesn't go through infinite loops" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    count = 0
    builder.runtime_interceptor do |name, val|
      if name == "myString"
        c = RuntimeInterceptorConfig.instance
        count += 1
        next c.myString # will trigger another lookup and interception of this variable
      end
    end

    r = builder.build
    RuntimeInterceptorConfig.set_instance(r)

    count.should eq 0
    r.myString.should eq "my super string"
    count.should eq 1
  end

  it "allows interceptors to be triggered once per property" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    count = 0
    builder.runtime_interceptor do |name, val|
      if name == "sub.myInts"
        c = RuntimeInterceptorConfig.instance
        count += 1
        c.myString # will trigger another lookup and interception of this variable
        next c.sub.myInts
      end
    end

    builder.runtime_interceptor do |name, val|
      if name == "myString"
        c = RuntimeInterceptorConfig.instance
        count += 1
        c.sub.myInts
        next c.myString
      end
    end

    r = builder.build
    RuntimeInterceptorConfig.set_instance(r)

    count.should eq 0
    r.sub.myInts.should eq [3]
    count.should eq 2 # 1 for the myString interceptor, 1 for the myInts interceptor
  end

  it "Allows overriding a bool to false" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end
    builder.runtime_interceptor do |name, val|
      next false if name == "myBool"
    end

    r = builder.build

    r.myBool?.should be_false
  end

  it "passes base type to interceptor" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("myString", "my super string")
      bob.set("sub.myInts", 3)
    end

    classes = Hash(String, String).new

    builder.runtime_interceptor do |name, val, clazz|
      classes[name] = clazz
      nil
    end

    r = builder.build

    r.myBool?
    r.myString
    r.sub.myInts

    classes.size.should eq 3
    classes.should eq ({"myString" => "String", "myBool" => "Bool", "sub.myInts" => "Array(Int32)"})
  end
end
