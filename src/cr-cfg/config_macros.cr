require "./builder_macro.cr"
require "./config_providers.cr"

module CrCfgV2
  include BuilderMacro
  include ConfigProvider

  alias PrimitiveTypes = String | Int32 | Int64 | Float32 | Float64 | Bool | UInt32 | UInt64

  {% begin %}
  alias AllTypes = PrimitiveTypes {% for t in PrimitiveTypes.union_types %}| Array({{t}}) {% end %}
  {% end %}
  {% begin %}
  SUPPORTED_TYPES = { {% for t in AllTypes.union_types %}"{{t}}",{% end %}}
  {% end %}

  Array(String) | Array(Int32) | Array(Int64) | Array(Float32) | Array(Float64) | Array(Bool) | Array(UInt32) | Array(UInt64)

  macro option(name, default = nil)
    {% CONFIG_PROPS[name.var] = {
         name:         name.var,
         type:         name.type,
         is_base_type: SUPPORTED_TYPES.includes?("#{name.type.types[0]}"),
         base_type:    name.type.types[0],
         nilable:      name.type.types.map { |x| "#{x.id}" }.includes?("Nil"),
         default:      default,
       } %}
  end

  macro _validate_properties
    {% for name, props in CONFIG_PROPS %}
      {% base_type = props[:base_type].id %}
      {% possible_base_type = @type.id.includes?("::") ? "#{@type.id.split("::")[0..-2].join("::").id}::#{base_type}".id : base_type %}
      {% sub_configs = CrCfgV2.includers.map { |x| x.id } %}
      {% unless SUPPORTED_TYPES.includes?("#{base_type}") || sub_configs.includes?(base_type) || sub_configs.includes?(possible_base_type) %}
        {% raise "Property #{name} in #{@type} is not a supported type (#{base_type}). Config types allowed are #{SUPPORTED_TYPES}, or any includers of CrCfgV2 (#{sub_configs})" %}
      {% end %}
    {% end %}
  end

  macro _generate_getters
    {% for name, val in CONFIG_PROPS %}
      {% if val[:is_base_type] %}
      @{{name}} : {{val[:type]}}

      def {{name}} : {{val[:type]}}
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
        return {{name}}
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

  macro included
    CONFIG_PROPS = {} of Nil => Nil

    macro finished
      _validate_properties

      _generate_getters

      _generate_constructor

      _generate_builder

      _generate_config_providers

      def self.load
        bob = {{@type.id.split("::")[-1].id}}ConfigBuilder.new("")

        @@_providers.each do |provider|
          provider.populate(bob)
        end

        bob.build
      end
    end
  end
end
