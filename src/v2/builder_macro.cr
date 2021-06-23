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
          "{{name}}" => ->(ignore : String, inst : {{@type}}Builder, x : AllTypes) { inst.{{name}} = x.as({{props[:type].types[0]}}); nil },
          {% else %}
          "{{name}}" => ->(name : String, inst : {{@type}}Builder, x : AllTypes) { inst.{{name}}.set(name, x); nil },
          {% end %}
        {% end %}
        } of String => Proc(String, {{@type}}Builder, AllTypes, Nil)
      {% end %}

      def properties : Hash(String, String)
        {{@type.id}}.named_fields
      end

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
        if @{{name}}.nil? && !({{props[:nilable]}})
          raise ConfigException.new "{{name}}", ConfigException::Type::ConfigNotFound, "Not found in any config source"
        end
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
