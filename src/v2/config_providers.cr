module CrCfgV2::ConfigProvider
  macro _generate_config_providers
    @@providers = [] of AbstractProvider

    class_getter providers


    def self.register_provider(provider)
      @@providers << provider
    end
  end
end
