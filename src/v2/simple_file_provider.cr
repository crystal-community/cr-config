module CrCfgV2
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
end
