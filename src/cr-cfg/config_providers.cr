module CrCfgV2::ConfigProvider
  macro _generate_config_providers
    @@_runtime_interceptors = [] of Proc(String, AllTypes?, AllTypes?)
    @@_providers = [] of AbstractProvider
    @@_validators = [] of Proc(String, AllTypes?, Nil)
    @@_instance : {{@type}}?
    class_getter _validators
    class_property _runtime_interceptors

    def self.instance : {{@type}}
      if i = @@_instance
        return i
      end
      @@_instance = self.load
      @@_instance.not_nil!
    end

    def self.reset
      @@_runtime_interceptors.clear
      @@_providers.clear
      @@_validators.clear
      @@_instance = nil
    end

    def self.validator(&block : (String, AllTypes?) -> Nil)
      @@_validators << block
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
