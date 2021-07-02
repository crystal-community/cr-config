require "./spec_helper"

class EnvVarProviderSpec
  include CrCfgV2

  option myUint : UInt64
  option mySubConfig : SubEnvVarConfig
end

class SubEnvVarConfig
  include CrCfgV2

  option someString : String?
  option someFloat : Float64
  option someFloatyString : String
end

describe "Environment Variable Provider" do
  it "parses environment variables" do
    EnvVarProviderSpec.providers do
      CrCfgV2::Providers::EnvVarProvider.new
    end

    ENV["MYUINT"] = "999999999999"
    ENV["MYSUBCONFIG_SOMEFLOAT"] = "3.1415926"
    ENV["MYSUBCONFIG_SOMEFLOATYSTRING"] = "3.1415926"

    e = EnvVarProviderSpec.load

    e.myUint.should eq 999999999999.to_u64
    e.mySubConfig.someFloat.should eq 3.1415926
    e.mySubConfig.someFloatyString.should eq "3.1415926"
    e.mySubConfig.someString.should be_nil
  end
end
