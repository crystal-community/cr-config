require "./abstract_provider.cr"
require "csv" # Used for parsing strings => Array(String) (let it deal with double quotes and whatnot)

module CrConfig
  # Exception that gets thrown whenever there's something "wrong" with the configuration, such as a
  # config value not being found through the providers, or not being able to be transformed into the
  # correct type.
  class ConfigException < Exception
    enum Type
      # Config name was not populated from any configuration provider
      ConfigNotFound

      # Could not parse / transform a provided configuration value into the correct type
      ParseError

      # Parsing received an Array object from a provider, but the real type is String. Since string
      # data was likely lost in the conversion to an Array, treat this as an error (instead, the
      # string containing the array should be passed directly to the builder)
      ArrayToString

      # A custom configuration validator threw an exception
      CustomValidationError
    end

    # The configuration property name that the error was triggered for
    getter :name

    # The Type of the error
    getter :type

    # Error message
    #
    # Hopefully a more human readable error message that helps identify what caused the problem and how to fix it
    getter :parse_message

    def initialize(@name : String, @type : Type, @parse_message : String)
      super("#{@type}: #{@name}: #{@parse_message}")
    end
  end

  # This module houses the collection of macros that construct the intermediate builder class for the
  # configuration class. Builders constructed from these macros extend the `AbstractBuilder` class.
  module BuilderMacro
    # Does exactly what its name implies
    macro _generate_builder
      class {{@type.id.split("::")[-1].id}}ConfigBuilder < AbstractBuilder
        @_base_name : String
        @_runtime_interceptors = [] of Proc(String, AllTypes?, AllTypes?)
        @_providers = [] of Providers::AbstractProvider
        @_validators = [] of Proc(String, AllTypes?, Nil)

        # Add a validator that will be called when building the config class. Validators will receive the config name and
        # the configured value, and can throw an exception if the configuration isn't valid.
        def validator(&block : (String, AllTypes?) -> Nil)
          @_validators << block
          self
        end

        # Add a runtime interceptor that will be called when any config property is accessed. Runtime interceptors will be
        # called with the config name and the existing config value. If the interceptor returns nil, the existing value gets
        # used. If the interceptor returns anything not-nil, that will override the existing value.
        #
        # Multiple runtime interceptors can be added, but only the first to return a non-nil value will override the value.
        def runtime_interceptor(&block : (String, AllTypes?) -> AllTypes?)
          @_runtime_interceptors << block
          self
        end

        # Add a configuration provider that will be invoked during the `build` method.
        def provider(provider : Providers::AbstractProvider)
          @_providers << provider
          self
        end

        # :ditto:
        def provider(&block : AbstractBuilder -> Nil)
          @_providers << Providers::ProcProvider.new(block)
          self
        end

        # Add a list of configuration providers through a block. The block should return a config provider, or an array of config
        # providers. This method overrides whatever the current list of providers is, and the order will be preserved during calling.
        def providers(&block)
          providers = yield
          if providers.is_a?(Array)
            @_providers = providers.map &.as(Providers::AbstractProvider)
          elsif providers.is_a?(Providers::AbstractProvider)
            @_providers = [providers.as(Providers::AbstractProvider)]
          end
          self
        end

        {% verbatim do %}
        macro _get_default_for_type(default, type)
          {% if default != nil %}
            {{default}}
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

          # Edge case that needs to be handled before the below block:
          # If original is an array and the intended type is a String, throw an exception, as it's unclear in what way the
          # array should be reformatted back into a String
          if original.is_a?(Array) && intended_type == String
            raise ConfigException.new(name_for_error, ConfigException::Type::ArrayToString, "Unable to coerce '#{original}' into a type of String, is currently a #{original.class}")
          end

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

          if intended_type.to_s.starts_with?("Array(") && original.is_a?(String)
            original = CSV.parse(original)[0]
          end

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
            return ["#{original}" == "true" ? true : false] if intended_type == Array(Bool)
            return [original.to_s] if intended_type == Array(String)
          end

          # We can get here if original is an array and the intended_type isn't
          raise ConfigException.new(name_for_error, ConfigException::Type::ParseError, "Unable to coerce '#{original}' into a type of #{intended_type}, is currently a #{original.class}")
        end

        {% for name, props in CONFIG_PROPS %}
        {% if props[:is_base_type] %}
        property {{name}} : {{props[:type]}}{% unless props[:nilable] %}?{% end %}
        {% else %}
        property {{name}} : {{props[:base_type]}}::{{props[:base_type].id.split("::")[-1].id}}ConfigBuilder
        {% end %}
        {% end %}


        def initialize(@_base_name : String)
          {% for name, props in CONFIG_PROPS %}
          {% if props[:is_base_type] %}
          @{{name}} = _get_default_for_type({{props[:default]}}, {{props[:base_type]}})
          {% else %}
          @{{name}} = {{props[:base_type]}}::{{props[:base_type].id.split("::")[-1].id}}ConfigBuilder.new("#{@_base_name}{{name}}.")
          {% end %}
          {% end %}
        end

        def set(name : String, val : AllTypes)
          if name.includes?('.')
            name, rest = name.split(".", 2)
          end

          {% begin %}
          2.times do
            case name.downcase
              {% for name, props in CONFIG_PROPS %}
              {% if props[:is_base_type] %}
              when "{{name.downcase}}"
                @{{name}} = {{@type.id.split("::")[-1].id}}ConfigBuilder.coerce(val, {{props[:base_type]}}, "{{name}}").as({{props[:base_type]}})
                return true
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
            # Either the property doesn't exist, or it has underscores that had been converted to '.'s
            name = "#{name}.#{rest}".gsub('.', '_')
            rest = nil
          end
          {% end %}
          return false
        end

        private def _validate_settings(validators)
          # TODO: gracefully generate a new config?
          {% for name, props in CONFIG_PROPS %}
          {% unless props[:nilable] %}
          if @{{name}}.nil? && !({{props[:nilable]}})
            raise ConfigException.new "#{@_base_name}{{name}}", ConfigException::Type::ConfigNotFound, "Not found in any config source"
          end
          {% end %}
          {% end %}

          {% for name, props in CONFIG_PROPS %}
          {% if props[:is_base_type] %}
          begin
            validators.each do |validator|
              validator.call("#{@_base_name}{{name}}", @{{name}})
            end
          rescue e : ConfigException
            raise e
          rescue e : Exception
            raise ConfigException.new("{{name}}", ConfigException::Type::CustomValidationError, e.message || e.to_s)
          end
          {% end %}
          {% end %}
        end

        def build(validators = @_validators, interceptors = @_runtime_interceptors)
          @_providers.each do |provider|
            provider.populate(self)
          end

          _validate_settings(validators)

          {{@type}}.new(
            @_base_name,
            interceptors,
            {% for name, props in CONFIG_PROPS %}
            {% if props[:is_base_type] %}
            @{{name}}{% if !props[:nilable] %}.not_nil!{% end %},
            {% else %}
            @{{name}}.build(validators, interceptors),
            {% end %}
            {% end %}
          )
        end
      end
    end
  end
end
