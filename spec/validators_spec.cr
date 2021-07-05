require "./spec_helper"

class ValidatorConfig
  include CrConfig

  option myStrings : Array(String)
  option sub : ValidatorSubConfig
end

class ValidatorSubConfig
  include CrConfig

  option myFloats : Array(Float64)
end

describe "Validators" do
  it "provides a validation check" do
    builder = ValidatorConfig.new_builder.provider do |bob|
      bob.set("myStrings", "yes")
      bob.set("sub.myFloats", "5")
    end

    # This is relying on the validators running in the order the configurations are defined in the config class
    builder.validator do |name, val|
      name.should eq "myStrings"
      raise "#{val.to_s} is an invalid config!"
    end

    begin
      v = builder.build
      fail("Should have received an exception during configuration loading")
    rescue e : CrConfig::ConfigException
      e.message.not_nil!.should end_with "[\"yes\"] is an invalid config!"
      e.type.should eq CrConfig::ConfigException::Type::CustomValidationError
      e.name.should eq "myStrings"
    end
  end

  it "enumerates through all configs" do
    builder = ValidatorConfig.new_builder.provider do |bob|
      bob.set("myStrings", "yes")
      bob.set("sub.myFloats", "5")
    end

    encountered = [] of String
    builder.validator do |name, val|
      encountered << name
    end

    v = builder.build

    v.myStrings.should eq ["yes"]
    v.sub.myFloats.should eq [5.0]

    encountered.should eq ["myStrings", "sub.myFloats"]
  end
end
