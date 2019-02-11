require "./spec_helper"

class Config5
  include CrCfg

  no_file

  option str_option : String, "Some String Description",
    flag: "-f STR"
end

describe "CrCfg 5" do
  it "doesn't require a file" do
    begin
      c = Config5.new

      ARGV << "-f"
      ARGV << "something"

      c.load

      c.str_option.should eq "something"
    ensure
      ARGV.clear
    end
  end
end
