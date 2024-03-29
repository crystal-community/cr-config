require "./spec_helper"

module MyModule
  module MyNestedModule
    class MyRealConfig
      include CrConfig

      option my_string : String
      option server : MySubConfig
    end

    class MySubConfig
      include CrConfig

      option host : String, default: "localhost"
      option host2 : String = "localhost"
      option port : Int32?
      option bool : Bool, default: false
    end
  end
end

module SeparateModule
  class MyOtherConfig
    include CrConfig

    option real : MyModule::MyNestedModule::MyRealConfig
  end
end

describe "Crystal Config Modules" do
  it "Handles modules and nested modules" do
    other_bob = MyModule::MyNestedModule::MyRealConfig.new_builder.provider do |bob|
      bob.set("my_string", "hope this works")
    end

    m = other_bob.build

    m.my_string.should eq "hope this works"
    m.server.host.should eq "localhost"
    m.server.host2.should eq "localhost"
    m.server.port.should be_nil
  end

  it "Handles other modules" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.my_string", "nope")
    end

    s = other_bob.build

    s.real.my_string.should eq "nope"
    s.real.server.host.should eq "yup"
    s.real.server.port.should be_nil
  end

  it "uses the same instance" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.my_string", "nope")
      bob.set("real.server.port", 8080)
    end
    SeparateModule::MyOtherConfig.set_instance(other_bob.build)

    s = SeparateModule::MyOtherConfig.instance

    s.real.my_string.should eq "nope"
    s.real.server.host.should eq "yup"
    s.real.server.port.should eq 8080

    s1 = SeparateModule::MyOtherConfig.instance
    s.object_id.should eq s1.object_id
  end

  it "exposes the full list of configuration names available" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.my_string", "nope") # case insensitive setting
      bob.set("real.server.port", 8080)
    end

    s = other_bob.build
    names = SeparateModule::MyOtherConfig.get_config_names

    names.should contain "real.server.host"
    names.should contain "real.server.host2"
    names.should contain "real.my_string"
    names.should contain "real.server.port"
    names.size.should eq 5

    s["real.server.host"].should eq "yup"
    s["real.server.host2"].should eq "localhost"
    s["real.server.port"].should eq 8080
    s["real.my_string"].should eq "nope"
  end

  it "missing key names refer to the full key name" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.my_string", "nope")
      bob.set("real.server.port", 8080)
    end

    s = other_bob.build

    begin
      s["real.server.nope"]
    rescue e : KeyError
      e.message.not_nil!.should contain "real.server.nope"
    end
  end

  it "[] works with bool subconfig names when they're false" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.my_string", "nope")
      bob.set("real.server.port", 8080)
    end

    s = other_bob.build

    s["real.server.bool"].should be_false
  end
end
