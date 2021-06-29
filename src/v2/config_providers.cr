module CrCfgV2::ConfigProvider
  macro _generate_config_providers
    @@_runtime_interceptors = [] of Proc(String, AllTypes?, AllTypes?)
    @@_providers = [] of AbstractProvider

    def self.reset
      @@_runtime_interceptors.clear
      @@_providers.clear
    end

    def self.runtime_interceptor(&block : (String, AllTypes?) -> AllTypes?)
      @@_runtime_interceptors << block
    end

    def self.provider(provider : AbstractProvider)
      @@_providers << provider
      {{@type}}
    end

    def self.provider(&block : AbstractBuilder -> Nil)
      @@_providers << ProcProvider.new(block)
      {{@type}}
    end

    def self.providers(&block)
      providers = yield
      if providers.is_a?(Array)
        @@_providers = providers.map &.as(AbstractProvider)
      elsif providers.is_a?(AbstractProvider)
        @@_providers = [providers.as(AbstractProvider)]
      end
    end

    def self.providers
      @@_providers
    end
  end
end
