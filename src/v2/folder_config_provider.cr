module CrCfgV2
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
