require "./spec_helper"

module MyModule
  module MyNestedModule
    class MyRealConfig
      include CrConfig

      option myString : String
      option server : MySubConfig
    end

    class MySubConfig
      include CrConfig

      option host : String, default: "localhost"
      option port : Int32?
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
      bob.set("myString", "hope this works")
    end

    m = other_bob.build

    m.myString.should eq "hope this works"
    m.server.host.should eq "localhost"
    m.server.port.should be_nil
  end

  it "Handles other modules" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.mystring", "nope")
    end

    s = other_bob.build

    s.real.myString.should eq "nope"
    s.real.server.host.should eq "yup"
    s.real.server.port.should be_nil
  end

  it "uses the same instance" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.mystring", "nope")
      bob.set("real.server.port", 8080)
    end
    SeparateModule::MyOtherConfig.set_instance(other_bob.build)

    s = SeparateModule::MyOtherConfig.instance

    s.real.myString.should eq "nope"
    s.real.server.host.should eq "yup"
    s.real.server.port.should eq 8080

    s1 = SeparateModule::MyOtherConfig.instance
    s.object_id.should eq s1.object_id
  end

  it "exposes the full list of configuration names available" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.mystring", "nope") # case insensitive setting
      bob.set("real.server.port", 8080)
    end

    s = other_bob.build
    names = SeparateModule::MyOtherConfig.get_config_names

    names.should contain "real.server.host"
    names.should contain "real.myString"
    names.should contain "real.server.port"
    names.size.should eq 3

    s["real.server.host"].should eq "yup"
    s["real.server.port"].should eq 8080
    s["real.myString"].should eq "nope"
  end

  it "missing key names refer to the full key name" do
    other_bob = SeparateModule::MyOtherConfig.new_builder.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.mystring", "nope") # case insensitive setting
      bob.set("real.server.port", 8080)
    end

    s = other_bob.build

    begin
      s["real.server.nope"]
    rescue e : KeyError
      e.message.not_nil!.should contain "real.server.nope"
    end
  end
end
