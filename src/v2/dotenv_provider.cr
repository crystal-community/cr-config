module CrCfgV2
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
end
