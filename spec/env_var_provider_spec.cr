require "./spec_helper"

class EnvVarProviderSpec
  include CrConfig

  option myUint : UInt64
  option mySubConfig : SubEnvVarConfig
end

class SubEnvVarConfig
  include CrConfig

  option someString : String?
  option someFloat : Float64
  option someFloatyString : String
  option some_underscored_name : String?
end

describe "Environment Variable Provider" do
  it "parses environment variables" do
    bob = EnvVarProviderSpec.new_builder
    bob.providers do
      CrConfig::Providers::EnvVarProvider.new
    end

    ENV["MYUINT"] = "999999999999"
    ENV["MYSUBCONFIG_SOMEFLOAT"] = "3.1415926"
    ENV["MYSUBCONFIG_SOMEFLOATYSTRING"] = "3.1415926"

    e = bob.build

    e.myUint.should eq 999999999999.to_u64
    e.mySubConfig.someFloat.should eq 3.1415926
    e.mySubConfig.someFloatyString.should eq "3.1415926"
    e.mySubConfig.someString.should be_nil
  end

  it "handles env var prefixes" do
    bob = EnvVarProviderSpec.new_builder
    bob.providers do
      [
        CrConfig::Providers::EnvVarProvider.new,
        CrConfig::Providers::EnvVarProvider.new("MY_SERVER_"),
      ]
    end

    ENV["MYUINT"] = "999999999999"
    ENV["MYSUBCONFIG_SOMEFLOAT"] = "3.1415926"
    ENV["MYSUBCONFIG_SOMEFLOATYSTRING"] = "3.1415926"

    ENV["MY_SERVER_MYUINT"] = "37"

    e = bob.build

    e.myUint.should eq 37.to_u64
    e.mySubConfig.someFloat.should eq 3.1415926
    e.mySubConfig.someFloatyString.should eq "3.1415926"
    e.mySubConfig.someString.should be_nil
  end

  it "correctly handles underscores in property names" do
    bob = EnvVarProviderSpec.new_builder
    bob.provider(CrConfig::Providers::EnvVarProvider.new)

    ENV["MYUINT"] = "999999999999"
    ENV["MYSUBCONFIG_SOMEFLOAT"] = "3.1415926"
    ENV["MYSUBCONFIG_SOMEFLOATYSTRING"] = "3.1415926"

    ENV["MYSUBCONFIG_SOME_UNDERSCORED_NAME"] = "test"

    e = bob.build

    e.mySubConfig.some_underscored_name.should eq "test"
  end
end
