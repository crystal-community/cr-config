require "./spec_helper"

class RuntimeInterceptorConfig
  include CrConfig

  option my_bool : Bool, default: true
  option my_string : String
  option my_nil_string : String?
  option sub : RuntimeInterceptorSubConfig
end

class RuntimeInterceptorSubConfig
  include CrConfig

  option my_ints : Array(Int32)
end

describe "Runtime Interceptors" do
  it "provides a single interception" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", [3])
    end.runtime_interceptor do |name|
      next "something else" if name == "my_string"
    end

    r = builder.build
    r.my_string.should eq "something else"
    r.sub.my_ints.should eq [3]
    r.my_bool?.should be_true
  end

  it "don't continue past returned one" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", [3])
    end

    count = 0
    builder.runtime_interceptor do
      count += 1
      nil
    end

    builder.runtime_interceptor do |name, val|
      count += 1
      next val.as(Array(Int32)) + [1, 2, 3] if name == "sub.my_ints"
    end

    builder.runtime_interceptor do
      count += 1
      nil
    end

    r = builder.build
    r.my_string.should eq "my super string"
    r.sub.my_ints.should eq [3, 1, 2, 3]
    count.should eq 5 # 2 props hit for first, 2 props for 2nd, 1 prop for the 3rd
  end

  it "can use next without providing nil" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end

    builder.runtime_interceptor do |name|
      next unless name == "my_string"

      "something else"
    end

    r = builder.build
    r.my_string.should eq "something else"
    r.sub.my_ints.should eq [3]
  end

  it "can be configured at runtime" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end

    return_something_else = false
    builder.runtime_interceptor do |name|
      next unless name == "my_string"
      "test" # placed here to make sure that it's not returned when return_something_else is false
      next "something else" if return_something_else
    end

    r = builder.build
    r.my_string.should eq "my super string"

    return_something_else = true
    r.my_string.should eq "something else"

    return_something_else = false
    r.my_string.should eq "my super string"
  end

  it "supports intercepting nilable values" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end

    builder.runtime_interceptor do |name|
      next unless name == "my_nil_string"
      "no longer nil"
    end

    r = builder.build
    r.my_nil_string.should eq "no longer nil"
  end

  it "doesn't go through infinite loops" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end

    count = 0
    builder.runtime_interceptor do |name|
      if name == "my_string"
        c = RuntimeInterceptorConfig.instance
        count += 1
        next c.my_string # will trigger another lookup and interception of this variable
      end
    end

    r = builder.build
    RuntimeInterceptorConfig.set_instance(r)

    count.should eq 0
    r.my_string.should eq "my super string"
    count.should eq 1
  end

  it "allows interceptors to be triggered once per property" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end

    count = 0
    builder.runtime_interceptor do |name|
      if name == "sub.my_ints"
        c = RuntimeInterceptorConfig.instance
        count += 1
        c.my_string # will trigger another lookup and interception of this variable
        next c.sub.my_ints
      end
    end

    builder.runtime_interceptor do |name|
      if name == "my_string"
        c = RuntimeInterceptorConfig.instance
        count += 1
        c.sub.my_ints
        next c.my_string
      end
    end

    r = builder.build
    RuntimeInterceptorConfig.set_instance(r)

    count.should eq 0
    r.sub.my_ints.should eq [3]
    count.should eq 2 # 1 for the my_string interceptor, 1 for the my_ints interceptor
  end

  it "Allows overriding a bool to false" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end
    builder.runtime_interceptor do |name|
      next false if name == "my_bool"
    end

    r = builder.build

    r.my_bool?.should be_false
  end

  it "passes base type to interceptor" do
    builder = RuntimeInterceptorConfig.new_builder.provider do |bob|
      bob.set("my_string", "my super string")
      bob.set("sub.my_ints", 3)
    end

    classes = Hash(String, String).new

    builder.runtime_interceptor do |name, _, clazz|
      classes[name] = clazz
      nil
    end

    r = builder.build

    r.my_bool?
    r.my_string
    r.sub.my_ints

    classes.size.should eq 3
    classes.should eq({"my_string" => "String", "my_bool" => "Bool", "sub.my_ints" => "Array(Int32)"})
  end
end
