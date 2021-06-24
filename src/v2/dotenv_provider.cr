require "csv"

module CrCfgV2
  class DotenvProvider < AbstractProvider
    def initialize(@source : String)
    end

    def populate(bob : AbstractBuilder)
      @source.split("\n").each do |line|
        next if line.starts_with?(/\s*#/) || line.strip.empty?

        prop, val = line.split(/\s*=\s*/)

        # Make CSV do the heavy lifting of determing if this is a list or not
        csv = CSV.parse(val)

        row = csv[0]

        row.size == 1 ? bob.set(prop, row[0].strip) : bob.set(prop, row.map { |x| x.strip })
      end
    end
  end
end
