require "../spec_helper"

class ValidatorConfig
  include CrCfgV2

  option myStrings : Array(String)
  option sub : ValidatorSubConfig
end

class ValidatorSubConfig
  include CrCfgV2

  option myFloats : Array(Float64)
end

describe "Validators" do
  Spec.before_each do
    ValidatorConfig.reset
  end

  it "provides a validation check" do
    ValidatorConfig.provider do |bob|
      bob.set("myStrings", "yes")
      bob.set("sub.myFloats", "5")
    end

    # This is relying on the validators running in the order the configurations are defined in the config class
    ValidatorConfig.validator do |name, val|
      name.should eq "myStrings"
      raise "#{val.to_s} is an invalid config!"
    end

    begin
      v = ValidatorConfig.load
      fail("Should have received an exception during configuration loading")
    rescue e : CrCfgV2::ConfigException
      e.message.not_nil!.should end_with "[\"yes\"] is an invalid config!"
      e.type.should eq CrCfgV2::ConfigException::Type::CustomValidationError
      e.name.should eq "myStrings"
    end
  end

  it "enumerates through all configs" do
    ValidatorConfig.provider do |bob|
      bob.set("myStrings", "yes")
      bob.set("sub.myFloats", "5")
    end

    encountered = [] of String
    ValidatorConfig.validator do |name, val|
      encountered << name
    end

    v = ValidatorConfig.load

    v.myStrings.should eq ["yes"]
    v.sub.myFloats.should eq [5.0]

    encountered.should eq ["myStrings", "sub.myFloats"]
  end
end
