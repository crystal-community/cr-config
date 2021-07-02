# This module houses the macros for the config class itself, including the static methods used for configuring
# the parsing, validating, and retreiving of config values.
module CrConfig::Macros
  # Generates class variable to store the providers, validators, interceptors, and the already parsed instance of
  # the config class, if already parsed.
  macro _generate_config_providers
    @@_runtime_interceptors = [] of Proc(String, AllTypes?, AllTypes?)
    @@_providers = [] of Providers::AbstractProvider
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

    def self.provider(provider : Providers::AbstractProvider)
      @@_providers << provider
      {{@type}}
    end

    def self.provider(&block : AbstractBuilder -> Nil)
      @@_providers << Providers::ProcProvider.new(block)
      {{@type}}
    end

    def self.providers(&block)
      providers = yield
      if providers.is_a?(Array)
        @@_providers = providers.map &.as(Providers::AbstractProvider)
      elsif providers.is_a?(Providers::AbstractProvider)
        @@_providers = [providers.as(Providers::AbstractProvider)]
      end
    end

    def self.providers
      @@_providers
    end
  end

  # Macro for validating all `option` properties are of valid types, being either something in `AllTypes`, or another configuration class
  macro _validate_properties
    {% for name, props in CONFIG_PROPS %}
      {% base_type = props[:base_type].id %}
      {% possible_base_type = @type.id.includes?("::") ? "#{@type.id.split("::")[0..-2].join("::").id}::#{base_type}".id : base_type %}
      {% sub_configs = CrConfig.includers.map { |x| x.id } %}
      {% unless SUPPORTED_TYPES.includes?("#{base_type}") || sub_configs.includes?(base_type) || sub_configs.includes?(possible_base_type) %}
        {% raise "Property #{name} in #{@type} is not a supported type (#{base_type}). Config types allowed are #{SUPPORTED_TYPES}, or any includers of CrConfig (#{sub_configs})" %}
      {% end %}
    {% end %}
  end

  # Generates getter methods for the config class. The `[]` and `[]?` methods are also generated, using the config name dot notation
  # to retreive the value.
  macro _generate_getters
    {% for name, val in CONFIG_PROPS %}
      {% if val[:is_base_type] %}
      @{{name}} : {{val[:type]}}

      def {{name}}{% if val[:base_type].id == Bool.id %}?{% end %} : {{val[:type]}}
        full_name = @_names["{{name}}"]
        @@_runtime_interceptors.each do |proc|
          if p = proc.call(full_name, @{{name}})
            return p.as({{val[:base_type]}})
          end
        end
        @{{name}}
      end
      {% else %}
      getter {{name}} : {{val[:type]}}
      {% end %}
    {% end %}

    def []?(key : String)
      true_key = key
      rest = ""
      true_key, rest = key.split('.', 2) if key.includes?('.')

      {% begin %}
      case true_key
      {% for name, props in CONFIG_PROPS %}
      {% if props[:is_base_type] %}
      when "{{name}}"
        # If we're here, and there's a '.' in the initial key, we're treating a primitive as a subconfiguration
        return nil if key.includes?('.')
        return {{name}}{% if props[:base_type].id == Bool.id %}?{% end %}
      {% else %}
      when "{{name}}"
        return @{{name}}[rest]
      {% end %}
      {% end %}
      else
        return nil
      end
      {% end %}
    end

    def [](key : String)
      if val = self[key]?
        return val
      end
      raise KeyError.new("Missing configuration key #{key}")
    end
  end

  # Generates the comprehensive and exhaustive `initialize` method for this configuration class. All properties are included
  macro _generate_constructor
    def initialize(base_name : String, {% for name, prop in CONFIG_PROPS %}
      @{{name}} : {{prop[:type]}},
    {% end %})
      # property name to fully qualified name (i.e. "prop2" => "prop1.sub.prop2")
      @_names = {} of String => String
      {% for name, prop in CONFIG_PROPS %}
      {% if prop[:is_base_type] %}
      @_names["{{name}}"] = "#{base_name}{{name}}"
      {% end %}
      {% end %}
    end
  end
end
