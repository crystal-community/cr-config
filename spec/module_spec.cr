require "./spec_helper"

module MyModule
  module MyNestedModule
    class MyRealConfig
      include CrCfgV2

      option myString : String
      option server : MySubConfig
    end

    class MySubConfig
      include CrCfgV2

      option host : String, default: "localhost"
      option port : Int32?
    end
  end
end

module SeparateModule
  class MyOtherConfig
    include CrCfgV2

    option real : MyModule::MyNestedModule::MyRealConfig
  end
end

describe "Crystal Config Version 2" do
  Spec.before_each do
    SeparateModule::MyOtherConfig.reset
    MyModule::MyNestedModule::MyRealConfig.reset
  end

  it "Handles modules and nested modules" do
    MyModule::MyNestedModule::MyRealConfig.provider do |bob|
      bob.set("myString", "hope this works")
    end

    m = MyModule::MyNestedModule::MyRealConfig.load

    m.myString.should eq "hope this works"
    m.server.host.should eq "localhost"
    m.server.port.should be_nil
  end

  it "Handles other modules" do
    SeparateModule::MyOtherConfig.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.mystring", "nope")
    end

    s = SeparateModule::MyOtherConfig.load

    s.real.myString.should eq "nope"
    s.real.server.host.should eq "yup"
    s.real.server.port.should be_nil
  end

  it "uses the same instance" do
    SeparateModule::MyOtherConfig.provider do |bob|
      bob.set("real.server.host", "yup")
      bob.set("real.mystring", "nope")
      bob.set("real.server.port", 8080)
    end

    s = SeparateModule::MyOtherConfig.instance

    s.real.myString.should eq "nope"
    s.real.server.host.should eq "yup"
    s.real.server.port.should eq 8080

    s1 = SeparateModule::MyOtherConfig.instance
    s.object_id.should eq s1.object_id
  end
end
