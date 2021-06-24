require "yaml"

module CrCfgV2
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
end
