require "../spec_helper"

class ArgvConfig
  include CrCfgV2

  option myString : String
  option myArr : Array(Int64)

  option sub : ArgvSubConfig
end

class ArgvSubConfig
  include CrCfgV2

  option importantThing : Float32
end

describe "Command Line Parser" do
  it "parses from ARGV" do
    ArgvConfig.providers do
      CrCfgV2::CommandLineParser.new
    end

    before_size = ARGV.size
    ARGV << "--mystring=abcde"
    ARGV << "myarr=4,8,20192,-445"
    ARGV << "--sub.importantThing=3.14159265"

    config = ArgvConfig.load

    config.myString.should eq "abcde"
    config.myArr.should eq [4, 8, 20192, -445]
    config.myArr.class.should eq Array(Int64)
    # Float32 rounding leads to ...5927, instead of ...59265
    config.sub.importantThing.should eq 3.1415927.to_f32

    ARGV.size.should eq before_size
  end
end
