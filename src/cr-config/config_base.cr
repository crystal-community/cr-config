require "./builder_macro.cr"
require "./config_macros.cr"

module CrConfig
  include BuilderMacro
  include Macros

  # Base types supported by configuration classes. These and `Array(*)` of these make up the `AllTypes` alias.
  alias PrimitiveTypes = String | Int32 | Int64 | Float32 | Float64 | Bool | UInt32 | UInt64

  {% begin %}
  # Represents all base types supported by configuration properties. All configurations must resolve
  # to one of these types eventually
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

  macro included
    CONFIG_PROPS = {} of Nil => Nil

    macro finished
      _validate_properties

      _generate_getters

      _generate_constructor

      _generate_builder

      _generate_config_providers

      def self.new_builder
        {{@type.id.split("::")[-1].id}}ConfigBuilder.new("")
      end
    end
  end
end
