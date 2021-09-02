require "./spec_helper"

class ProfileFileConfigSpec
  include CrConfig

  option myString : String
end

describe "File Config Provider" do
  it "loads a single file" do
    builder = ProfileFileConfigSpec.new_builder.providers do
      CrConfig::Providers::ProfileFileConfigProvider.new
        .folder("spec/test_files/configs")
        .base_file("config.env")
    end

    f = builder.build

    f.myString.should eq "it worked!"
  end

  it "loads files in a particular order" do
    builder = ProfileFileConfigSpec.new_builder.providers do
      CrConfig::Providers::ProfileFileConfigProvider.new
        .folder("spec/test_files/configs")
        .base_file("config.env")
        .separator("-")
        .profiles do
          ["test", "local"]
        end
    end

    f = builder.build

    f.myString.should eq "this is the local environment"

    builder = ProfileFileConfigSpec.new_builder.providers do
      CrConfig::Providers::ProfileFileConfigProvider.new
        .folder("spec/test_files/configs")
        .base_file("config.env")
        .separator("-")
        .profiles do
          ["local", "test"]
        end
    end

    f = builder.build

    f.myString.should eq "this is the testing environment"
  end
end
