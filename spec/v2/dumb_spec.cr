require "../spec_helper"

class Test
  include CrCfgV2

  option prop1 : String?
  option prop2 : Int32
  option prop3 : Int64
  option prop4 : Float32
  option prop5 : Float64
  option prop6 : Bool
  option prop7 : UInt32, default: 37_u32
  option prop8 : UInt64

  option prop9 : SubTest

  option prop10 : Float64, default: Float64::NAN
  option prop11 : Array(UInt32)
end

class SubTest
  include CrCfgV2

  option prop1 : String, default: "this is a default"
  option prop2 : Int32
  option prop3 : Array(String)
  option prop4 : Array(Int64)?
end

# parsable by dotenv
dotenv_raw = <<-EOF
prop1 = "test"
prop2 = 2
prop3 = 3
prop4 = 1
prop5 = 0.003
prop6 = true
prop7 = 7
prop8 = 999999999999999999
prop11 = 1, 2, 3, 5, 8

prop9.prop1 = same test
prop9.prop2 = 37
prop9.prop3 = test1,"test 2",test3
EOF

# parsable by YAML
yaml_raw = <<-EOF
prop1: test
prop2: 2
prop3: 3
prop4: 1
prop5: 0.003
prop6: true
prop7: 7
prop8: 999999999999999999
prop9:
  prop1: same test
  prop2: 37
  prop3:
   - test1
   - test 2
   - test3
prop11:
  - 1
  - 2
  - 3
  - 5
  - 8
EOF

# parsable by JSON
json_raw = <<-EOF
{
  "prop1": "test",
  "prop2": 2,
  "prop3": 3,
  "prop4": 1,
  "prop5": 0.003,
  "prop6": true,
  "prop7": 7,
  "prop8": 999999999999999999,
  "prop9": {
    "prop1": "same test",
    "prop2": 37,
    "prop3": [
      "test1",
      "test 2",
      "test3"
    ]
  },
  "prop11": [
    1,
    2,
    3,
    5,
    8
  ]
}
EOF

class DumbConfigProvider < CrCfgV2::AbstractProvider
  def populate(bob : CrCfgV2::AbstractBuilder)
    bob.set("prop2", 3)
    bob.set("prop3", 4.to_i64)
    bob.set("prop4", 3.to_f32)
    bob.set("prop5", 37.0.to_f64)
    bob.set("prop6", true)
    bob.set("prop7", 9999999.to_u32)
    bob.set("prop8", 111111111.to_u64)
    bob.set("prop9.prop2", 50)
    bob.set("prop9.prop3", ["this is ", "an", " array"])
    bob.set("prop11", [1, 2, 3, 5, 8])
  end
end

describe "CrCfg V2" do
  it "gets setup by the dumb provider" do
    Test.providers.clear
    Test.register_provider(DumbConfigProvider.new)

    t1 = Test.load
    t1.prop1.should be_nil
    t1.prop2.should eq 3
    t1.prop3.should eq 4
    t1.prop6.should be_true
    t1.prop9.prop2.should eq 50

    t1["prop1"]?.should be_nil
    t1["prop2"].should eq 3
    t1["prop9.prop2"].should eq 50
  end

  it "parses and sets JSON" do
    Test.providers.clear
    Test.register_provider(CrCfgV2::JsonProvider.new(json_raw))

    t = Test.load
    t.prop1.should eq "test"
    t["prop9.prop3"].should eq ["test1", "test 2", "test3"]
    t["prop11"].class.should eq Array(UInt32)
  end
end
