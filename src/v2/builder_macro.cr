require "./abstract_provider.cr"

module CrCfgV2::BuilderMacro
  class ConfigException < Exception
    enum Type
      ConfigNotFound
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

      # NOTE: The compiler is not nice if you try to be too clever and abstract out these common blocks of casting
      # into another macro / method / recursively, and compile times may increase. Compile with `--stats` to see
      # length of time of various compile steps
      def self.coerce(original : AllTypes, intended_type : Class, name_for_error : String) : AllTypes
        return original if original.class == intended_type

        # TODO: try and be more intelligent about types (i.e. if original is already of type Int, don't convert to String
        # to then convert to Int32)
        return "#{original}".to_i32 if intended_type == Int32
        return "#{original}".to_i64 if intended_type == Int64
        return "#{original}".to_u32 if intended_type == UInt32
        return "#{original}".to_u64 if intended_type == UInt64
        return "#{original}".to_f32 if intended_type == Float32
        return "#{original}".to_f64 if intended_type == Float64
        return original.to_s if intended_type == String
        return ("#{original}" == "true" ? true : false) if intended_type == Bool

        if original.is_a?(Array) && intended_type.to_s.starts_with?("Array(")
          {% for i in PrimitiveTypes.union_types %}
          if intended_type == Array({{i}})
            a = [] of {{i}}
            original.each do |x|
              {% if i == Int32 %}a << "#{x}".to_i32{% end %}
              {% if i == Int64 %}a << "#{x}".to_i64{% end %}
              {% if i == Float32 %}a << "#{x}".to_f32{% end %}
              {% if i == Float64 %}a << "#{x}".to_f64{% end %}
              {% if i == UInt32 %}a << "#{x}".to_u32{% end %}
              {% if i == UInt64 %}a << "#{x}".to_u64{% end %}
              {% if i == Bool %}a << ("#{x}" == "true" ? true : false){% end %}
              {% if i == String %}a << x.to_s{% end %}
            end
            return a
          end
          {% end %}
        elsif intended_type.to_s.starts_with?("Array(")
          return ["#{original}".to_i32] if intended_type == Array(Int32)
          return ["#{original}".to_i64] if intended_type == Array(Int64)
          return ["#{original}".to_f32] if intended_type == Array(Float32)
          return ["#{original}".to_f64] if intended_type == Array(Float64)
          return ["#{original}".to_u32] if intended_type == Array(UInt32)
          return ["#{original}".to_u64] if intended_type == Array(UInt64)
          return [original.to_s] if intended_type == Array(String)
          return ["#{original}" == "true" ? true : false] if intended_type == Array(Bool)
        end

        # Compiler should prevent us from getting here
        raise ConfigException.new(name_for_error, ConfigException::Type::ParseError, "Unable to coerce '#{original}' into a type of #{intended_type}, is currently a #{original.class}")
      end

      {% for name, props in CONFIG_PROPS %}
      {% if props[:is_base_type] %}
      property {{name}} : {{props[:type]}}{% unless props[:nilable] %}?{% end %} = _get_default_for_type({{props[:default]}}, {{props[:base_type]}})
      {% else %}
      property {{name}} : {{props[:base_type]}}::{{props[:base_type]}}Builder = _get_default_for_type({{props[:default]}}, {{props[:base_type]}})
      {% end %}
      {% end %}

      def set(name : String, val : AllTypes)
        if name.includes?('.')
          name, rest = name.split(".", 2)
        end

        {% begin %}
        case name.downcase
          {% for name, props in CONFIG_PROPS %}
          {% if props[:is_base_type] %}
          when "{{name.downcase}}"
            @{{name}} = {{@type}}Builder.coerce(val, {{props[:base_type]}}, "{{name}}").as({{props[:base_type]}})
          {% else %}
          when "{{name.downcase}}"
            # Check if we were able to parse a subpath from the given path
            if r = rest
              return @{{name}}.set(rest, val)
            end
          {% end %}
          {% end %}
          # purposely ignore trying to set non-existent values. Could be a dirty config, but not a reason to crash the server
        end
        {% end %}
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
          {% if props[:is_base_type] %}
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
