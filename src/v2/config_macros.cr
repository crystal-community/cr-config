require "./builder_macro.cr"
require "./config_providers.cr"

module CrCfgV2
  include BuilderMacro
  include ConfigProvider

  SUPPORTED_TYPES = {"String", "Int32", "Int64", "Float32", "Float64", "Bool", "UInt32", "UInt64", "Array(String)", "Array(Int32)", "Array(Int64)", "Array(Float32)", "Array(Float64)", "Array(Bool)", "Array(UInt32)", "Array(UInt64)"}
  alias AllTypes = String | Int32 | Int64 | Float32 | Float64 | Bool | UInt32 | UInt64 | Array(String) | Array(Int32) | Array(Int64) | Array(Float32) | Array(Float64) | Array(Bool) | Array(UInt32) | Array(UInt64)
  alias PrimitiveTypes = String | Int32 | Int64 | Float32 | Float64 | Bool | UInt32 | UInt64

  macro option(name, default = nil)
    {% CONFIG_PROPS[name.var] = {
         name:    name.var,
         type:    name.type,
         nilable: name.type.types.map { |x| "#{x.id}" }.includes?("Nil"),
         default: default,
       } %}
  end

  macro _generate_getters
    {% for name, val in CONFIG_PROPS %}
      getter {{name}} : {{val[:type]}}
    {% end %}

    def []?(key : String)
      true_key = key
      rest = ""
      true_key, rest = key.split('.', 2) if key.includes?('.')


      {% begin %}
      case true_key
      {% for name, props in CONFIG_PROPS %}
      {% if SUPPORTED_TYPES.includes?("#{props[:type].types[0]}") %}
      when "{{name}}"
        # If we're here, and there's a '.' in the initial key, we're treating a primitive as a subconfiguration
        return nil if key.includes?('.')
        return @{{name}}
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
    def initialize({% for name, prop in CONFIG_PROPS %}
      @{{name}} : {{prop[:type]}},
    {% end %})
    end
  end

  macro included
    CONFIG_PROPS = {} of Nil => Nil

    macro finished
      _generate_getters

      _generate_constructor

      _generate_builder

      _generate_config_providers

      def self.load
        bob = {{@type}}Builder.new

        @@providers.each do |provider|
          provider.populate(bob)
        end

        bob.build
      end
    end
  end
end
