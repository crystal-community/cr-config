require "option_parser"

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

  macro no_file
    NO_FILE = true
  end

  macro header(desc)
    HEADER = {{desc}}
  end

  macro footer(desc)
    FOOTER = {{desc}}
  end

  macro exit_on_help
    EXIT_ON_HELP = true
  end

  macro option(name, description = nil, default = nil, required = false, flag = nil, shortflag = nil, longflag = nil)
    {% raise "#{name.type} is not supported as a config type" unless SUPPORTED_TYPES.includes?(name.type) %}
    {% default = false if default == nil && "#{name.type}" == "Bool" %}
    {% CONFIG_PROPS[name.var] = {
         name:        name.var,
         type:        name.type,
         description: description,
         default:     default,
         required:    required,
         flag:        flag,
         shortflag:   shortflag,
         longflag:    longflag,
       } %}
  end

  macro included
    CONFIG_PROPS = {} of Nil => Nil
    SUPPORTED_TYPES = [String, Int32, Float64, Bool]

    macro finished
      {% verbatim do %}
        @_arg_parser = OptionParser.new


        {% for name, settings in CONFIG_PROPS %}
          getter {{name}}
          {% if settings[:type].id == "String" %}
            @{{name}} = {% if settings[:default] != nil %}"{{settings[:default].id}}"{% else %}""{% end %}
          {% elsif settings[:type].id == "Int32" %}
            @{{name}} = {% if settings[:default] != nil %}{{settings[:default].id}}{% else %}0{% end %}
          {% elsif settings[:type].id == "Float64" %}
            @{{name}} = {% if settings[:default] != nil %}{{settings[:default].id}}{% elsif settings[:required] %}Float64::NAN{% else %}0.0{% end %}
          {% elsif settings[:type].id == "Bool" %}
            @{{name}} = {% if settings[:default] != nil %}{{settings[:default].id}}{% else %}false{% end %}
          {% end %}
        {% end %}
      {% end %}

      def load
        {% if @type.has_constant?(:NO_FILE) %}
          load(IO::Memory.new)
        {% else %}
        load(\{% if @type.has_constant?(:DEFAULT_NAME) %}DEFAULT_NAME\{% else %}"config.txt"\{% end %})
        {% end %}
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
        \{% if @type.has_constant?(:HEADER) %}
          @_arg_parser.banner = HEADER
        \{% end %}
        @_arg_parser.on("-h", "--help", "Prints this message") do
          puts @_arg_parser
          {% if @type.has_constant?(:EXIT_ON_HELP) %}
            exit(0)
          {% end %}
        end
        \{% for name, settings in CONFIG_PROPS %}
            \{% if settings[:flag] != nil %}
              \{% raise "#{settings[:name]} must define a description if it's using the flag option" if settings[:description] == nil %}
              @_arg_parser.on(_create_flag(\{{settings[:flag]}}, "\{{settings[:type].id}}"), \{{settings[:description]}}) do |s|
                \{% if settings[:type].id == "String" %}
                  @\{{name}} = s
                \{% elsif settings[:type].id == "Int32" %}
                  @\{{name}} = s.to_i
                \{% elsif settings[:type].id == "Float64" %}
                  @\{{name}} = s.to_f
                \{% elsif settings[:type].id == "Bool" %}
                  @\{{name}} = true
                \{% end %}
              end
            \{% elsif settings[:shortflag] != nil && settings[:longflag] != nil %}
              \{% raise "#{settings[:name]} must define a description if it's using the shortflag and longflag options" if settings[:description] == nil %}
              @_arg_parser.on(_create_flag(\{{settings[:shortflag]}}, "\{{settings[:type]}}"),
                _create_flag(\{{settings[:longflag]}}, "\{{settings[:type]}}"),
                \{{settings[:description]}}) do |s|
                \{% if settings[:type].id == "String" %}
                  @\{{name}} = s
                \{% elsif settings[:type].id == "Int32" %}
                  @\{{name}} = s.to_i
                \{% elsif settings[:type].id == "Float64" %}
                  @\{{name}} = s.to_f
                \{% elsif settings[:type].id == "Bool" %}
                  @\{{name}} = (s == "true")
                \{% end %}
              end
            \{% end %}
        \{% end %}

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
              @\{{name}} = (line.split("=")[1].strip.downcase == "true") if line.starts_with?("\{{name}}")
            \{% end %}
            rescue e : Exception
              raise ConfigException.new("\{{name}}", ConfigException::Type::ParseError, "Error while parsing \{{name}}: #{e.message}")
            end
          \{% end %}
        end

        # Check environment variables to see if propreties were set there
        \{% for name, settings in CONFIG_PROPS %}
            begin
            \{% if settings[:type].id == "String" %}
              @\{{name}} = ENV["\{{name.id}}".upcase].strip if ENV.has_key?("\{{name.id}}".upcase)
            \{% elsif settings[:type].id == "Int32" %}
              @\{{name}} = ENV["\{{name.id}}".upcase].strip.to_i if ENV.has_key?("\{{name.id}}".upcase)
            \{% elsif settings[:type].id == "Float64" %}
              @\{{name}} = ENV["\{{name.id}}".upcase].strip.to_f if ENV.has_key?("\{{name.id}}".upcase)
            \{% elsif settings[:type].id == "Bool" %}
              @\{{name}} = (ENV["\{{name.id}}".upcase].strip.downcase == "true") if ENV.has_key?("\{{name.id}}".upcase)
            \{% end %}
            rescue e : Exception
              raise ConfigException.new("\{{name}}", ConfigException::Type::ParseError, "Error while parsing \{{name}}: #{e.message}")
            end
        \{% end %}

        # Clone the ARGV array so other option parsers may use it
        argv = ARGV.map { |x| x }
        @_arg_parser.parse(argv)

        \{% for name, settings in CONFIG_PROPS %}
          \{% if settings[:required] == true && settings[:default] == nil %}
            raise ConfigException.new("\{{name}}", ConfigException::Type::OptionNotFound, "Never parsed \{{name}} (\{{settings[:type]}}), which is a required setting") if @\{{name}} == "" || (@\{{name}}.is_a?(Float) && @\{{name}}.as(Float).nan?)
          \{% end %}
        \{% end %}
      end

      private def _create_flag(flag : String, t : String)
        return flag if t == "Bool"
        return "#{flag} #{flag.gsub("-","").upcase}"
      end

      def generate_config() : IO
        io = IO::Memory.new

        \{% if @type.has_constant?(:HEADER) %}
          io.puts(HEADER.gsub(/^\s*([^#])/m, "# \\1"))
        \{% end %}
        \{% for name, settings in CONFIG_PROPS %}
          io.puts if io.size > 0 && "\{{settings[:description].id}}" != "nil"
          \{% if settings[:description] != nil && settings[:description].size > 0%}
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
