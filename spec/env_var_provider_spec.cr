require "./spec_helper"

class EnvVarProviderSpec
  include CrConfig

  option my_uint : UInt64
  option my_sub_config : SubEnvVarConfig
end

class SubEnvVarConfig
  include CrConfig

  option some_string : String?
  option some_float : Float64
  option some_floaty_string : String
  option some_underscored_name : String?
end

describe "Environment Variable Provider" do
  it "parses environment variables" do
    bob = EnvVarProviderSpec.new_builder
    bob.providers do
      CrConfig::Providers::EnvVarProvider.new
    end

    ENV["MY_UINT"] = "999999999999"
    ENV["MY_SUB_CONFIG__SOME_FLOAT"] = "3.1415926"
    ENV["MY_SUB_CONFIG__SOME_FLOATY_STRING"] = "3.1415926"

    e = bob.build

    e.my_uint.should eq 999999999999.to_u64
    e.my_sub_config.some_float.should eq 3.1415926
    e.my_sub_config.some_floaty_string.should eq "3.1415926"
    e.my_sub_config.some_string.should be_nil
  end

  it "handles env var prefixes" do
    bob = EnvVarProviderSpec.new_builder
    bob.providers do
      [
        CrConfig::Providers::EnvVarProvider.new,
        CrConfig::Providers::EnvVarProvider.new("MY_SERVER_"),
      ]
    end

    ENV["MY_UINT"] = "999999999999"
    ENV["MY_SUB_CONFIG__SOME_FLOAT"] = "3.1415926"
    ENV["MY_SUB_CONFIG__SOME_FLOATY_STRING"] = "3.1415926"

    ENV["MY_SERVER_MY_UINT"] = "37"

    e = bob.build

    e.my_uint.should eq 37.to_u64
    e.my_sub_config.some_float.should eq 3.1415926
    e.my_sub_config.some_floaty_string.should eq "3.1415926"
    e.my_sub_config.some_string.should be_nil
  end

  it "correctly handles underscores in property names" do
    bob = EnvVarProviderSpec.new_builder
    bob.provider(CrConfig::Providers::EnvVarProvider.new)

    ENV["MY_UINT"] = "999999999999"
    ENV["MY_SUB_CONFIG__SOME_FLOAT"] = "3.1415926"
    ENV["MY_SUB_CONFIG__SOME_FLOATY_STRING"] = "3.1415926"

    ENV["MY_SUB_CONFIG__SOME_UNDERSCORED_NAME"] = "test"

    e = bob.build

    e.my_sub_config.some_underscored_name.should eq "test"
  end
end
