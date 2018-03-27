require "./spec_helper"

class Config1
  include CrCfg

  option str_option : String, "Some String Description"
end

describe "CrCfg 1" do
  it "generates config" do
    c = Config1.new

    config = c.generate_config

    config.to_s.should eq "# Some String Description
str_option = VALUE
"
  end

  it "parses empty config" do
    c = Config1.new

    c.load(IO::Memory.new)

    c.str_option.should eq ""
  end

  it "parses file of only comments" do
    c = Config1.new

    c.load(IO::Memory.new("# Comment
# another comment

#
     # comment indented"))

    c.str_option.should eq ""
  end

  it "parses file" do
    c = Config1.new

    c.load(IO::Memory.new("str_option = Test value"))

    c.str_option.should eq "Test value"
  end
end
