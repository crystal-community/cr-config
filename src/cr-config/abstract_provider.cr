require "json"
require "yaml"

module CrConfig
  # Base class for configuration builders. All includers of CrConfig will have a builder
  # generated for them extending this class.
  #
  # This builder represents a "safe" instantiation of a config class, where all types are
  # nilable and mutable. Use the `build` method to contruct the immutable form of your config.
  abstract class AbstractBuilder
    # Build an instance of the config class. This method will:
    # 1. Iterate and invoke all available and configured providers for this config class
    # 2. Run validators on the resulting set of configuration values, both standard and custom
    # 3. Construct and wire in the runtime interceptors of the concrete config class
    abstract def build

    # Generic setter method to set one configuration property. *name* is the fully qualified
    # name of the config, while *val* is any valid base type.
    abstract def set(name : String, val : AllTypes)
  end

  module Providers
    # Base class for all providers.
    #
    # A configuration provider represents a single source for where configuration values can be
    # read from, whether it be from a configuration file (`SimpleFileProvider`), and environment
    # variable (`EnvVarProvider`), or even a custom location (see `ProcProvider`). Configuration
    # providers have their `populate` method invoked during the building of the configuration class
    # which lets them provide what config values they have available.
    abstract class AbstractProvider
      # This method gets called with the instance of the configuration builder during config building.
      #
      # Use this method to populate the builder with any configuration name / values that this provider... provides
      abstract def populate(bob : AbstractBuilder)
    end

    # Provider class that wraps a `Proc(AbstractBuilder, Nil)`
    #
    # This class is used to store the block that gets passed in through the `MyConfig.provider` method
    class ProcProvider < AbstractProvider
      # :nodoc:
      def initialize(@proc : Proc(AbstractBuilder, Nil))
      end

      def populate(bob : AbstractBuilder)
        @proc.call(bob)
      end
    end

    # Provider that looks up configurations from environment variables
    #
    # Environment variable names are downcased and `_` characters get replaced by a `.`. i.e. CLIENT_HOST will change into client.host .
    # Can optionally be constructed with a prefix that will be removed from environment variable names so it can align with the correct
    # configuration name.
    #
    # ```
    # # constructing this...
    # CrConfig::Providers::EnvVarProvider.new("MY_SERVER_")
    #
    # # ...will cause this environment variable to be set for "client.host"
    # ENV["MY_SERVER_CLIENT_HOST"] = "different.example.com"
    # ```
    class EnvVarProvider < AbstractProvider
      # *prefix* is an optional parameter for defining the environment variable prefixes
      def initialize(@prefix = "")
      end

      def populate(bob : AbstractBuilder)
        ENV.each do |env_name, env_val|
          # Trim off the env name prefix so it can line up with the real configuration name
          env_name = env_name.gsub(@prefix, "")
          name = env_name.downcase.gsub(/_/, '.')
          bob.set(name, env_val)
        end
      end
    end

    # Provider that looks through provided command line arguments for configuration overrides
    #
    # This provider assumes all configurations will be supplied in the format of `--config.name=new_val` . To make this approach workable with OptionParser,
    # any configurations discovered through command line arguments will be removed from the ARGV array, so that OptionParser won't error for unrecognized options.
    # This requires the configuration class to be constructed _before_ the `OptionParser.parse` method gets called.
    class CommandLineParser < AbstractProvider
      def populate(bob : AbstractBuilder)
        consumed = [] of String
        ARGV.each do |arg|
          if arg.includes?("=")
            name, val = arg.split(/\s*=\s*/, 2)
            name = name[2..-1] if name.starts_with?("--")

            consumed << arg if bob.set(name, val)
          end
        end
        consumed.each { |arg| ARGV.delete(arg) }
      end
    end

    # Converts a JSON string into configuration values that can be used
    class JsonProvider < AbstractProvider
      # Construct this with the JSON string or IO that will be parsed and used in the populate method
      def initialize(json_source : String | IO)
        @json_source = JSON.parse(json_source)
      end

      def populate(bob : AbstractBuilder)
        h = {} of String => JSON::Any

        add_or_recurse(h, "", @json_source)

        h.each do |key, val|
          if val.as_a?
            a = val.as_a.map { |x| x.to_s }
            bob.set(key, a)
          else
            bob.set(key, val.raw.as(AllTypes))
          end
        end
      end

      # Will construct the full json path name as it recursively goes down the tree
      private def add_or_recurse(map, prefix, node)
        node.as_h.each do |k, v|
          if t = v.as_h?
            add_or_recurse(map, "#{prefix}#{prefix.empty? ? "" : "."}#{k}", v)
          else
            map["#{prefix}#{prefix.empty? ? "" : "."}#{k}"] = v
          end
        end
      end
    end

    # Converts a YAML string into configuration values that can be used
    class YamlProvider < AbstractProvider
      # Construct this with the YAML string that will be parsed and used in the populate method
      def initialize(yaml_source : String)
        @yaml_source = YAML.parse(yaml_source)
      end

      def populate(bob : AbstractBuilder)
        h = {} of String => YAML::Any

        add_or_recurse(h, "", @yaml_source)

        h.each do |key, val|
          if val.as_a?
            a = val.as_a.map { |x| x.to_s }
            bob.set(key, a)
          else
            bob.set(key, val.raw.as(AllTypes))
          end
        end
      end

      private def add_or_recurse(map, prefix, node)
        node.as_h.each do |k, v|
          if t = v.as_h?
            add_or_recurse(map, "#{prefix}#{prefix.empty? ? "" : "."}#{k}", v)
          else
            map["#{prefix}#{prefix.empty? ? "" : "."}#{k}"] = v
          end
        end
      end
    end

    # Converts a .env string into configuration values that can be used
    #
    # This provider will treat each line as a configuration name / value pair, and assumes each line is of the format:
    # ```
    # # Comments are supported in this format, any line beginning with a '#' will be ignored
    # configuration.name.here = my configuration value
    # ```
    class DotenvProvider < AbstractProvider
      # Construct this with the contents of an .env file
      def initialize(@source : String)
      end

      def populate(bob : AbstractBuilder)
        @source.split("\n").each do |line|
          next if line.starts_with?(/\s*#/) || line.strip.empty?

          prop, val = line.split(/\s*=\s*/)
          bob.set(prop, val)
        end
      end
    end

    # Provider that delegates to the `JsonProvider`, `YamlProvider`, and the `DotenvProvider` based on file extension
    #
    # This provider will handle reading in a file and using the appropriate standard configuration provider based on the file
    # extension of the *file_name*
    #
    # Mapping for file extensions works as:
    # .json               => `JsonProvider`
    # .yaml or .yml       => `YamlProvider`
    # .env or .properties => `DotenvProvider`
    class SimpleFileProvider < AbstractProvider
      # *file_name* is relative to where the application is running from
      def initialize(@file_name : String)
      end

      def populate(bob : AbstractBuilder)
        return unless File.exists?(@file_name)

        file_contents = File.read(@file_name)

        case @file_name
        when .ends_with?(".json")
          deleg = JsonProvider.new(file_contents)
          deleg.populate(bob)
        when .ends_with?(".yaml"), .ends_with?(".yml")
          deleg = YamlProvider.new(file_contents)
          deleg.populate(bob)
        when .ends_with?(".env"), .ends_with?(".properties")
          deleg = DotenvProvider.new(file_contents)
          deleg.populate(bob)
        else
          raise "Unsupported file type #{@file_name}, expected \".json\", \".yaml\", \".yml\", or \".env\""
        end
      end
    end

    # Handles and loads up an entire directory of configuration files
    #
    # This provider is best used when there is a single "base" configuration file that has all configurations
    # defined, and then other configuration files can be layered on top of that one, providing overrides based
    # on the environment the application runs in.
    #
    # This provider has lots of configuration switches that can be used when loading files from a directory
    # ```
    # # Assume directory `configs` exists and contains `config-base.yaml`, `config-test.yaml`, `config-local.yaml`, and `config-prod.yaml`
    #
    # CrConfig::Providers::FolderConfigProvirer.new
    #   .folder("configs")
    #   .separator("-")
    #   .base_file("config.yaml")
    #   .profiles do
    #     # Here is where a list of "profiles" of configurations can be provided.
    #     # These can be obtained from anywhere that's appropriate (obviously before
    #     # configuration has completed being read in), such as an environment variable.
    #     ["base", "test", "prod"]
    #   end
    # ```
    # The above provider, when its `populate` method is called, will read in and load `config-base.yaml`, `config-test.yaml`, and `config-prod.yaml`,
    # in that order, leaving the production configurations as having the highest precedence. `config-local.yaml` won't be read, and a file named
    # `config.yaml` doesn't need to exist.
    class FolderConfigProvider < AbstractProvider
      @profile_separator = "."

      # Seperator to use when constructing the different profile versions of the config file. See `#populate` for details on file construction
      def separator(@profile_separator : String)
        self
      end

      # Base folder path to read config files from, relative from where the server is running from
      def folder(@folder_path : String)
        self
      end

      # Base name for the configuration files
      def base_file(@base_file : String)
        self
      end

      # Block to be run when determining which "profiles" to load
      def profiles(&block : -> Array(String))
        @profiles = block
        self
      end

      # Will read in and and load files, used the `SimpleFileProvider` to perform the actual file reading, configuration files under
      # `"#{@filder_path}/#{file_name}"`, for every file name constructed from the `@base_file` and list of `profiles` provided.
      #
      # Given base file name `config.json`, a list of profiles `["prof1"]`, and separator of `_`, this will attempt to load all files
      # in `["config_prof1.json"]` under the provided folder_path. The profiles and separator are inserted where the file extension is found in the base file name.
      def populate(bob : AbstractBuilder)
        if @folder_path && File.exists?(@folder_path.not_nil!) && @base_file
          if profs = @profiles
            profiles = profs.call
          else
            profiles = [] of String
          end

          profiles.unshift("")
          base_file = @base_file.not_nil!
          suffix, name = base_file.reverse.split(".", 2)
          name = name.reverse
          suffix = suffix.reverse

          profiles.each do |profile|
            profile = "#{@profile_separator}#{profile}" if profile.size > 0
            file_name = "#{name}#{profile}.#{suffix}"

            s = CrConfig::Providers::SimpleFileProvider.new("#{@folder_path}/#{file_name}")

            s.populate(bob)
          end
        end
      end
    end
  end
end
