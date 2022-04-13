require "./spec_helper"

class ValidatorConfig
  include CrConfig

  option my_string : Array(String)
  option sub : ValidatorSubConfig
end

class ValidatorSubConfig
  include CrConfig

  option my_floats : Array(Float64)
end

describe "Validators" do
  it "provides a validation check" do
    builder = ValidatorConfig.new_builder.provider do |bob|
      bob.set("my_string", "yes")
      bob.set("sub.my_floats", "5")
    end

    # This is relying on the validators running in the order the configurations are defined in the config class
    builder.validator do |name, val|
      name.should eq "my_string"
      raise "#{val} is an invalid config!"
    end

    begin
      builder.build
      fail("Should have received an exception during configuration loading")
    rescue e : CrConfig::ConfigException
      e.message.not_nil!.should end_with "[\"yes\"] is an invalid config!"
      e.type.should eq CrConfig::ConfigException::Type::CustomValidationError
      e.name.should eq "my_string"
    end
  end

  it "enumerates through all configs" do
    builder = ValidatorConfig.new_builder.provider do |bob|
      bob.set("my_string", "yes")
      bob.set("sub.my_floats", "5")
    end

    encountered = [] of String
    builder.validator do |name|
      encountered << name
    end

    v = builder.build

    v.my_string.should eq ["yes"]
    v.sub.my_floats.should eq [5.0]

    encountered.should eq ["my_string", "sub.my_floats"]
  end
end
