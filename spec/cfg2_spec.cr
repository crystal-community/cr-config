require "./spec_helper"

class Config2
  include CrCfg

  header "descriptive header
  with multiple lines
  explaining stuff and things
  and maybe the MIT license"

  option str_option : String,
    description: "Some String Description"

  option int_option : Int32,
    default: 12345

  option float_option : Float64,
    required: true,
    description: "Multi
        line
comment"

  footer "Not sure who would use the footer, but here it is"
end

describe "CrCfg 2" do
  it "generates complex config" do
    c = Config2.new

    io = c.generate_config

    io.to_s.should eq "# descriptive header
# with multiple lines
# explaining stuff and things
# and maybe the MIT license

# Some String Description
str_option = VALUE
int_option = 12345

# Multi
# line
# comment
float_option = VALUE

# Not sure who would use the footer, but here it is
"
  end

  it "requires option" do
    c = Config2.new

    begin
      c.load(IO::Memory.new)
      raise "Should have failed"
    rescue e : CrCfg::ConfigException
      e.name.should eq "float_option"
      e.type.should eq CrCfg::ConfigException::Type::OptionNotFound
    end
  end

  it "has defaults" do
    c = Config2.new

    c.load(IO::Memory.new("float_option = 4"))

    c.str_option.should eq ""
    c.int_option.should eq 12345
    c.float_option.should eq 4.0
  end

  it "handles parse exceptions" do
    c = Config2.new

    begin
      c.load(IO::Memory.new("int_option = NaN"))
    rescue e : CrCfg::ConfigException
      e.name.should eq "int_option"
      e.type.should eq CrCfg::ConfigException::Type::ParseError
      e.parse_message.includes?("Invalid Int32: NaN").should eq true
    end
  end
end
