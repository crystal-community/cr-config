require "yaml"
require "json"

require "./v2/**"

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
end

class SubTest
  include CrCfgV2

  option prop1 : String, default: "this is a default"
  option prop2 : Int32
  option prop3 : Array(String)
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
prop8 = 99999999999999999999999999

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
prop8: 99999999999999999999999999
prop9:
  prop1: same test
  prop2: 37
  prop3:
   - test1
   - test 2
   - test3
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
  "prop8": 99999999999999999999999999,
  "prop9": {
    "prop1": "same test",
    "prop2": 37,
    "prop3": [
      "test1",
      "test 2",
      "test3"
    ]
  }
}
EOF

t1 = Test.load
t2 = Test.load
t3 = Test.load

puts(t1.inspect)
puts(t2.inspect)
puts(t3.inspect)
