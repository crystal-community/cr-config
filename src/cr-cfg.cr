module CrCfg
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

  macro file_name(name)
    DEFAULT_NAME = {{name}}
  end

  macro header(desc)
    HEADER = {{desc}}
  end

  macro footer(desc)
    FOOTER = {{desc}}
  end

  macro option(name, description = nil, default = nil, required = false)
    {% raise "#{name.type} is not supported as a config type" unless SUPPORTED_TYPES.includes?(name.type) %}
    {% CONFIG_PROPS[name.var] = {
         name:        name.var,
         type:        name.type,
         description: description,
         default:     default,
         required:    required,
       } %}
  end

  macro included
    CONFIG_PROPS = {} of Nil => Nil
    SUPPORTED_TYPES = [String, Int32, Float64, Bool]

    macro finished
      \{% for name, settings in CONFIG_PROPS %}
        getter \{{name}}
        \{% if settings[:type].id == "String" %}
          @\{{name}} = \{% if settings[:default] != nil %}"\{{settings[:default].id}}"\{% else %}""\{% end %}
        \{% elsif settings[:type].id == "Int32" %}
          @\{{name}} = \{% if settings[:default] != nil %}\{{settings[:default].id}}\{% else %}0\{% end %}
        \{% elsif settings[:type].id == "Float64" %}
          @\{{name}} = \{% if settings[:default] != nil %}\{{settings[:default].id}}\{% else %}0.0\{% end %}
        \{% elsif settings[:type].id == "Bool" %}
          @\{{name}} = \{% if settings[:default] != nil %}\{{settings[:default].id}}\{% else %}false\{% end %}
        \{% end %}
      \{% end %}

      def load
        load(\{% if @type.has_constant?(:DEFAULT_NAME) %}DEFAULT_NAME\{% else %}"config.txt"\{% end %})
      end

      def load(file_name : String)
        if !File.exists?(file_name)
          File.open(file_name, "w") do |file|
            file.puts(generate_config)
          end
          raise ConfigException.new(file_name, ConfigException::Type::ConfigNotFound, "Failed to parse #{file_name}, generated sample config instead")
        end

        load(File.open(file_name, "r"))
      end

      def load(input : IO)
        input.each_line do |line|
          next if line.starts_with?("#")
          \{% for name, settings in CONFIG_PROPS %}
            begin
            \{% if settings[:type].id == "String" %}
              @\{{name}} = line.split("=")[1].strip if line.starts_with?("\{{name}}")
            \{% elsif settings[:type].id == "Int32" %}
              @\{{name}} = line.split("=")[1].strip.to_i if line.starts_with?("\{{name}}")
            \{% elsif settings[:type].id == "Float64" %}
              @\{{name}} = line.split("=")[1].strip.to_f if line.starts_with?("\{{name}}")
            \{% elsif settings[:type].id == "Bool" %}
              @\{{name}} = line.split("=")[1].strip.to_b if line.starts_with?("\{{name}}")
            \{% end %}
            rescue e : Exception
              raise ConfigException.new("\{{name}}", ConfigException::Type::ParseError, "Error while parsing \{{name}}: #{e.message}")
            end
          \{% end %}
        end
        \{% for name, settings in CONFIG_PROPS %}
          \{% if settings[:required] == true && settings[:default] == nil %}
            raise ConfigException.new("\{{name}}", ConfigException::Type::OptionNotFound, "Never parsed \{{name}} (\{{settings[:type]}}), which is a required setting") if @\{{name}} == "" || @\{{name}} == 0
          \{% end %}
        \{% end %}
      end

      def generate_config() : IO
        io = IO::Memory.new

        \{% if @type.has_constant?(:HEADER) %}
          io.puts(HEADER.gsub(/^\s*([^#])/m, "# \\1"))
        \{% end %}
        \{% for name, settings in CONFIG_PROPS %}
          io.puts if io.size > 0 && "\{{settings[:description].id}}" != "nil"
          \{% if settings[:description] != nil %}
            io.puts("\{{settings[:description].id}}".gsub(/^\s*([^#])/m, "# \\1"))
          \{% end %}
          io.puts("\{{settings[:name]}} = \{% if settings[:default] == nil %}VALUE\{% else %}\{{settings[:default].id}}\{% end %}")
        \{% end %}
        \{% if @type.has_constant?(:FOOTER) %}
          io.puts if io.size > 0
          io.puts(FOOTER.gsub(/^\s*([^#])/m, "# \\1"))
        \{% end %}

        return io
      end
    end
  end
end
