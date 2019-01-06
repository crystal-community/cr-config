require "./spec_helper"

class Config4
  include CrCfg

  option str_option : String, "Some String Description",
    flag: "-s"
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

describe "Ordering" do
  Spec.after_each do
    ENV.clear
    ARGV.clear
  end

  it "environment variables trump config file" do
    c = Config4.new

    set_env({"STR_OPTION" => "right"})

    c.load(IO::Memory.new("str_option = incorrect"))

    c.str_option.should eq "right"
  end

  it "command line arguments trump config file" do
    c = Config4.new

    set_argv(["-s", "right"])

    c.load(IO::Memory.new("str_option = incorrect"))

    c.str_option.should eq "right"
  end

  it "command line arguments trump environment variables" do
    c = Config4.new

    set_env({"STR_OPTION" => "still incorrect"})
    set_argv(["-s", "right"])

    c.load(IO::Memory.new("str_option = incorrect"))

    c.str_option.should eq "right"
  end
end
