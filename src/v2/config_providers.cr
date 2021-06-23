module CrCfgV2::ConfigProvider
  macro _generate_config_providers
    @@providers = [] of AbstractProvider

    class DumbConfigProvider < AbstractProvider


      def populate(bob : AbstractBuilder)
        bob.set("prop2", 3)
        bob.set("prop3", 4.to_i64)
        bob.set("prop4", 3.to_f32)
        bob.set("prop5", 37.0.to_f64)
        bob.set("prop6", true)
        bob.set("prop7", 9999999.to_u32)
        bob.set("prop8", 111111111.to_u64)
        bob.set("prop9.prop2", 50)
        bob.set("prop9.prop3", ["this is ", "an", " array"])
      end
    end
  #     option prop1 : String?
  # option prop2 : Int32
  # option prop3 : Int64
  # option prop4 : Float32
  # option prop5 : Float64
  # option prop6 : Bool
  # option prop7 : UInt32, default: 37_u32
  # option prop8 : UInt64

  # option prop9 : SubTest

  # option prop10 : Float64, default: Float64::NAN


    def self.register_provider(provider)
      @@providers << provider
    end
  end
end
