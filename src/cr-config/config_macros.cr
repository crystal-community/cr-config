# This module houses the macros for the config class itself, including the static methods used for configuring
# the parsing, validating, and retreiving of config values.
module CrConfig::Macros
  # Generates class variable to store the providers, validators, interceptors, and the already parsed instance of
  # the config class, if already parsed.
  macro _generate_config_providers
    @_runtime_interceptors = [] of Proc(String, AllTypes?, String, AllTypes?)
    @@_config_names = Set(String).new
    @@_instance : {{@type}}?

    def self.instance : {{@type}}
      if i = @@_instance
        return i
      end
      raise ConfigException.new("{{@type}}", ConfigException::Type::ConfigNotFound, "{{@type}} config instance not set, use `{{@type}}.set_instance` to set it")
    end

    def self.set_instance(@@_instance : {{@type}})
    end

    def self.get_config_names
      @@_config_names
    end
  end

  # Macro for validating all `option` properties are of valid types, being either something in `AllTypes`, or another configuration class
  macro _validate_properties
    {% for name, props in CONFIG_PROPS %}
      {% base_type = props[:base_type].id %}
      {% possible_base_type = @type.id.includes?("::") ? "#{@type.id.split("::")[0..-2].join("::").id}::#{base_type}".id : base_type %}
      {% sub_configs = CrConfig.includers.map(&.id) %}
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

      @_processing_interceptor = Set(String).new
      def {{name}}{% if val[:base_type].id == Bool.id %}?{% end %} : {{val[:type]}}
        full_name = @_names["{{name}}"]
        return @{{name}} if @_processing_interceptor.includes?("{{name}}")
        begin
          # We'll allow interceptors to be run once per config.
          # If an interceptor also consults the config instance for certain properties, it will trigger
          # an infinite loop of looking up a config will invoke interceptors that lookup configs that...
          @_processing_interceptor << "{{name}}"
          @_runtime_interceptors.each do |proc|
            p = proc.call(full_name, @{{name}}, "{{val[:base_type].id}}")
            unless p.nil? # If an interceptor returns false, we want to treat that as an override
              return p.as({{val[:base_type]}})
            end
          end
        ensure
          @_processing_interceptor.delete("{{name}}")
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
      case true_key.downcase
      {% for name, props in CONFIG_PROPS %}
      {% if props[:is_base_type] %}
      when "{{name.downcase}}"
        # If we're here, and there's a '.' in the initial key, we're treating a primitive as a subconfiguration
        return nil if key.includes?('.')
        return {{name}}{% if props[:base_type].id == Bool.id %}?{% end %}
      {% else %}
      when "{{name.downcase}}"
        return @{{name}}[rest]?
      {% end %}
      {% end %}
      else
        return nil
      end
      {% end %}
    end

    def [](key : String)
      val = self[key]?
      if val || val == false
        return val.not_nil!
      end
      raise KeyError.new("Missing configuration key #{key}")
    end
  end

  # Generates the comprehensive and exhaustive `initialize` method for this configuration class. All properties are included
  macro _generate_constructor
    def initialize(base_name : String, @_runtime_interceptors : Array(Proc(String, AllTypes?, String, AllTypes?)), {% for name, prop in CONFIG_PROPS %}
      @{{name}} : {{prop[:type]}},
    {% end %})
      # property name to fully qualified name (i.e. "prop2" => "prop1.sub.prop2")
      @_names = {} of String => String
      {% for name, prop in CONFIG_PROPS %}
      {% if prop[:is_base_type] %}
      @_names["{{name}}"] = "#{base_name}{{name}}"
      @@_config_names << "{{name}}"
      {% else %}
      {{prop[:base_type]}}.get_config_names.each do |name|
        @@_config_names << "{{name}}.#{name}"
      end
      {% end %}
      {% end %}
    end
  end
end
