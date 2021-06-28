module CrCfgV2
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
end
