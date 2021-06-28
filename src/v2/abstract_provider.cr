require "json"
require "yaml"

module CrCfgV2
  abstract class AbstractBuilder
    abstract def build

    abstract def set(name : String, val : AllTypes)
  end

  abstract class AbstractProvider
    abstract def populate(bob : AbstractBuilder)
  end

  class ProcProvider < AbstractProvider
    def initialize(@proc : Proc(AbstractBuilder, Nil))
    end

    def populate(bob : AbstractBuilder)
      @proc.call(bob)
    end
  end

  class EnvVarProvider < AbstractProvider
    def populate(bob : AbstractBuilder)
      ENV.each do |env_name, env_val|
        name = env_name.downcase.gsub(/_/, '.')
        bob.set(name, env_val)
      end
    end
  end

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

  class JsonProvider < AbstractProvider
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

  class YamlProvider < AbstractProvider
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

  class DotenvProvider < AbstractProvider
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

  class SimpleFileProvider < AbstractProvider
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
      when .ends_with?(".env")
        deleg = DotenvProvider.new(file_contents)
        deleg.populate(bob)
      else
        raise "Unsupported file type #{@file_name}, expected \".json\", \".yaml\", \".yml\", or \".env\""
      end
    end
  end

  class FolderConfigProvider < AbstractProvider
    @profile_separator = "."

    def separator(@profile_separator : String)
      self
    end

    def folder(@folder_path : String)
      self
    end

    def base_file(@base_file : String)
      self
    end

    def profiles(&block : -> Array(String))
      @profiles = block
      self
    end

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

          s = CrCfgV2::SimpleFileProvider.new("#{@folder_path}/#{file_name}")

          s.populate(bob)
        end
      end
    end
  end
end
