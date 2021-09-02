require "./spec_helper"

class FolderConfigSpec
  include CrConfig

  option property1 : Bool
  option property2 : Int32
  option property3 : String
  option property4 : String?
end

describe CrConfig::Providers::FolderConfigProvider do
  it "reads all files in a directory" do
    builder = FolderConfigSpec.new_builder.providers do
      CrConfig::Providers::FolderConfigProvider.new("spec/test_files/folder_spec")
    end

    f = builder.build

    f.property1?.should be_true
    f.property2.should eq 3
    f.property3.should eq "My Super Cool Config"
    f.property4.should be_nil
  end
end
