require "./spec_helper"

class SimpleFileProviderConfig
  include CrConfig

  option str_option : String
  option arr_int32 : Array(Int32)
  option nilable : String?
end

describe "Simple File Provider" do
  it "parses json" do
    bob = SimpleFileProviderConfig.new_builder.provider(CrConfig::Providers::SimpleFileProvider.new("spec/test_files/simple_file_provider_spec/test.json"))

    s = bob.build

    s.str_option.should eq "this is a string"
    s.arr_int32.should eq [20394, 80980]
    s.nilable.should be_nil
  end

  it "parses yaml" do
    bob = SimpleFileProviderConfig.new_builder.provider(CrConfig::Providers::SimpleFileProvider.new("spec/test_files/simple_file_provider_spec/test.yaml"))

    s = bob.build

    s.str_option.should eq "this is a string"
    s.arr_int32.should eq [20394, 80980]
    s.nilable.should be_nil
  end

  it "parses env" do
    bob = SimpleFileProviderConfig.new_builder.provider(CrConfig::Providers::SimpleFileProvider.new("spec/test_files/simple_file_provider_spec/test.env"))

    s = bob.build

    s.str_option.should eq "this is a string"
    s.arr_int32.should eq [20394, 80980]
    s.nilable.should be_nil
  end
end

# Re-using the simple config above
describe "Config Builder" do
  it "merges multiple sources" do
    bob = SimpleFileProviderConfig.new_builder.providers do
      [
        CrConfig::Providers::DotenvProvider.new("str_option=this is a string"),
        CrConfig::Providers::DotenvProvider.new("arr_int32=3"),
      ]
    end

    s = bob.build

    s.str_option.should eq "this is a string"
    s.arr_int32.should eq [3]
  end

  it "requires non-nilable fields to be provided" do
    begin
      SimpleFileProviderConfig.new_builder.build
    rescue e : CrConfig::ConfigException
      e.type.should eq CrConfig::ConfigException::Type::ConfigNotFound
      e.name.should eq "str_option"
    end
  end

  it "uses config precedence" do
    bob = SimpleFileProviderConfig.new_builder.providers do
      [
        CrConfig::Providers::DotenvProvider.new("str_option=this is a string"),
        CrConfig::Providers::DotenvProvider.new("arr_int32=3"),
        CrConfig::Providers::DotenvProvider.new("arr_int32=5, 6, 7"),
      ]
    end

    s = bob.build

    s.str_option.should eq "this is a string"
    s.arr_int32.should eq [5, 6, 7]
  end
end
