module CrCfgV2::ConfigProvider
  macro _generate_config_providers
    PROVIDERS = [] of AbstractProvider

    def self.register_provider(provider)
      PROVIDERS << provider
    end

    def self.provider(&block : AbstractBuilder -> Nil)
      PROVIDERS << ProcProvider.new(block)
    end

    def self.providers
      yield PROVIDERS
    end

    def self.providers
      PROVIDERS
    end
  end
end
