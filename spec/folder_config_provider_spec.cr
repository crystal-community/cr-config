require "./spec_helper"

class FolderConfigProviderSpec
  include CrCfgV2

  option myString : String
end

describe "File Config Provider" do
  it "loads a single file" do
    FolderConfigProviderSpec.providers do
      CrCfgV2::FolderConfigProvider.new
        .folder("spec/test_files/configs")
        .base_file("config.env")
    end

    f = FolderConfigProviderSpec.load

    f.myString.should eq "it worked!"
  end

  it "loads files in a particular order" do
    FolderConfigProviderSpec.providers do
      CrCfgV2::FolderConfigProvider.new
        .folder("spec/test_files/configs")
        .base_file("config.env")
        .separator("-")
        .profiles do
          ["test", "local"]
        end
    end

    f = FolderConfigProviderSpec.load

    f.myString.should eq "this is the local environment"

    FolderConfigProviderSpec.providers do
      CrCfgV2::FolderConfigProvider.new
        .folder("spec/test_files/configs")
        .base_file("config.env")
        .separator("-")
        .profiles do
          ["local", "test"]
        end
    end

    f = FolderConfigProviderSpec.load

    f.myString.should eq "this is the testing environment"
  end
end
