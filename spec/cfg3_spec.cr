require "./spec_helper"

class Config3
  include CrCfg

  header "descriptive header
  with multiple lines
  explaining stuff and things
  and maybe the MIT license"

  option str_option : String,
    description: "Some String Description",
    flag: "-s"

  option int_option : Int32,
    default: 12345,
    shortflag: "-i",
    longflag: "--int",
    description: "Int option"

  option float_option : Float64,
    required: true,
    description: "Multi
        line
comment"

  option bool_option : Bool,
    flag: "-b",
    description: "Bool option"

  option env_var : String,
    description: "should be obtained from environment variable",
    required: true

  option env_int_var : Int32,
    description: "Make sure env vars are being parsed correctly",
    required: true

  footer "Not sure who would use the footer, but here it is"
end

def set_argv(args : Array(String))
  ARGV.clear
  args.each { |x| ARGV << x }
  ARGV
end

def set_env(props : Hash(String, String))
  ENV.clear
  props.each do |k, v|
    ENV[k] = v
  end
  ENV
end

describe "CrCfg 3" do
  it "parses args" do
    c = Config3.new
    old_argv = ARGV
    begin
      set_argv(["-s", "string", "--int", "2", "-b"])
      set_env({"ENV_VAR" => "env variable", "ENV_INT_VAR" => "37"})
      c.load(IO::Memory.new("float_option = 4.0"))
      c.str_option.should eq "string"
      c.int_option.should eq 2
      c.float_option.should eq 4.0
      c.bool_option.should eq true
      c.env_var.should eq "env variable"
      c.env_int_var.should eq 37
    rescue e : Exception
      raise e
    ensure
      set_argv(old_argv)
    end
  end
end
