require "./spec_helper"

class ArgvConfig
  include CrConfig

  option my_string : String
  option my_arr : Array(Int64)

  option sub : ArgvSubConfig
end

class ArgvSubConfig
  include CrConfig

  option important_thing : Float32
end

describe "Command Line Parser" do
  it "parses from ARGV" do
    bob = ArgvConfig.new_builder
    bob.providers do
      CrConfig::Providers::CommandLineParser.new
    end

    before_size = ARGV.size
    ARGV << "--my_string=abcde"
    ARGV << "my_arr=4,8,20192,-445"
    ARGV << "--sub.important_thing=3.14159265"

    config = bob.build

    config.my_string.should eq "abcde"
    config.my_arr.should eq [4, 8, 20192, -445]
    config.my_arr.class.should eq Array(Int64)
    # Float32 rounding leads to ...5927, instead of ...59265
    config.sub.important_thing.should eq 3.1415927.to_f32

    ARGV.size.should eq before_size
  end
end
