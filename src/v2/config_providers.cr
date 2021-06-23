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

    def self.register_provider(provider)
      @@providers << provider
    end
  end
end
