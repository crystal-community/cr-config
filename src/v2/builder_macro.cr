require "./abstract_provider.cr"

module CrCfgV2::BuilderMacro
  class ConfigException < Exception
    enum Type
      ConfigNotFound
      OptionNotFound
      ParseError
    end

    getter :name, :type, :parse_message

    def initialize(@name : String, @type : Type, @parse_message : String)
      super("#{@type}: #{@name}: #{@parse_message}")
    end
  end

  macro _generate_builder

    class {{@type.id}}Builder < AbstractBuilder
      {% verbatim do %}
      macro _get_default_for_type(default, type)
        {% if default != nil %}
          {{default}}
        {% elsif !SUPPORTED_TYPES.includes?("#{type}") %}
          {{type}}::{{type}}Builder.new
        {% else %}
          nil
        {% end %}
      end

      {% end %}

      def self.coerce(original : AllTypes, intended_type : Class) : AllTypes
        return original if original.class == intended_type

        # TODO: try and be more intelligent about types (i.e. if original is already of type Int, don't convert to String
        # to then convert to Int32)
        return "#{original}".to_i32 if intended_type == Int32
        return "#{original}".to_i64 if intended_type == Int64
        return "#{original}".to_f32 if intended_type == Float32
        return "#{original}".to_f64 if intended_type == Float64
        return "#{original}".to_u32 if intended_type == UInt32
        return "#{original}".to_u64 if intended_type == UInt64
        return original.to_s if intended_type == String
        return !{"false", "0"}.includes?("#{original}") if intended_type == Bool

        if original.is_a?(Array) && intended_type.to_s.starts_with?("Array(")
          {% for i in PrimitiveTypes.union_types %}
          if intended_type == Array({{i}})
            a = [] of {{i}}
            original.each { |x| a << coerce(x, {{i}}).as({{i}}) }
            return a
          end
          {% end %}
        elsif intended_type.to_s.starts_with?("Array(")
          # Edge case, we have a single value that should really be in an array
          {% for i in PrimitiveTypes.union_types %}
          if intended_type == Array({{i}})
            a = [] of {{i}}
            a << coerce(original, {{i}}).as({{i}})
            return a
          end
          {% end %}
        end

        # Compiler should protect us here
        raise "Unable to coerce '#{original}' into a type of #{intended_type}"
      end

      {% for name, props in CONFIG_PROPS %}
      {% if SUPPORTED_TYPES.includes?("#{props[:type].types[0]}") %}
      property {{name}} : {{props[:type]}}{% unless props[:nilable] %}?{% end %} = _get_default_for_type({{props[:default]}}, {{props[:type].types[0]}})
      {% else %}
      property {{name}} : {{props[:type].types[0]}}::{{props[:type].types[0]}}Builder = _get_default_for_type({{props[:default]}}, {{props[:type].types[0]}})
      {% end %}
      {% end %}

      {% begin %}
        @_setters = {
        {% for name, props in CONFIG_PROPS %}
          {% if SUPPORTED_TYPES.includes?("#{props[:type].types[0]}") %}
          "{{name}}" => ->(ignore : String, inst : {{@type}}Builder, x : AllTypes) { inst.{{name}} = coerce(x, {{props[:type].types[0]}}).as({{props[:type].types[0]}}); nil },
          {% else %}
          "{{name}}" => ->(name : String, inst : {{@type}}Builder, x : AllTypes) { inst.{{name}}.set(name, x); nil },
          {% end %}
        {% end %}
        } of String => Proc(String, {{@type}}Builder, AllTypes, Nil)
      {% end %}

      def set(name : String, val : AllTypes)
        if name.includes?('.')
          prop, rest = name.split(".", 2)
          @_setters[prop].call(rest, self, val)
        else
          @_setters[name].call("", self, val)
        end
      end

      def validate_settings
        # TODO: gracefully generate a new config?
        {% for name, props in CONFIG_PROPS %}
        {% unless props[:nilable] %}
        if @{{name}}.nil? && !({{props[:nilable]}})
          raise ConfigException.new "{{name}}", ConfigException::Type::ConfigNotFound, "Not found in any config source"
        end
        {% end %}
        {% end %}
      end

      def build
        validate_settings

        {{@type}}.new(
          {% for name, props in CONFIG_PROPS %}
          {% if SUPPORTED_TYPES.includes?("#{props[:type].types[0]}") %}
          @{{name}}{% if !props[:nilable] %}.not_nil!{% end %},
          {% else %}
          @{{name}}.build,
          {% end %}
          {% end %}
        )
      end
    end
  end
end
