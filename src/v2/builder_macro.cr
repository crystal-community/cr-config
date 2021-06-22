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
      macro _get_default_for_type(default)
        {% if default != nil %}
          {{default}}
        {% else %}
          nil
        {% end %}
      end

      macro is_nilable?(type)
        {% puts type.types %}
        {{type.types.map { |x| "#{x.id}" }.includes?("Nil")}}
      end
      {% end %}

      {% for name, props in CONFIG_PROPS %}
      getter {{name}} : {{props[:type]}}? = _get_default_for_type({{props[:default]}})

      def with_{{name}}(@{{name}} : {{props[:type]}})
        self
      end
      {% end %}

      def validate_settings
        # TODO: gracefully generate a new config?
        {% for name, props in CONFIG_PROPS %}
        {% puts props %}
        if @{{name}}.nil? && !({{props[:nilable]}})
          raise ConfigException.new "{{name}}", ConfigException::Type::ConfigNotFound, "Not found in any config source"
        end
        {% end %}
      end

      def build
        validate_settings

        {{@type}}.new(
          {% for name, props in CONFIG_PROPS %}
          @{{name}}{% if !props[:nilable] %}.not_nil!{% end %},
          {% end %}
        )
      end
    end
  end
end
