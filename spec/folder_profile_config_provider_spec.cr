require "./spec_helper"

module FolderProfileConfigProviderSpec
  class Root
    include CrConfig

    option server : Server
    option database : Database
    option misc : Misc
  end

  class Server
    include CrConfig

    option host : String
    option port : Int32
  end

  class Database
    include CrConfig

    option host : String
    option username : String
    option password : String
  end

  class Misc
    include CrConfig

    option anumber : Int32
    option astring : String
  end

  describe CrConfig::Providers::FolderProfileConfigProvider do
    it "loads no profiles" do
      builder = Root.new_builder.provider(CrConfig::Providers::FolderProfileConfigProvider.new
        .folder("spec/test_files/folder_profile_spec")
        .base_file("config.yml")
      )

      root = builder.build

      root.server.host.should eq "server"
      root.server.port.should eq 1234
      root.database.host.should eq "the real host"
      root.database.username.should eq "db_prod"
      root.database.password.should eq "cleartext password"
      root.misc.anumber.should eq 37
      root.misc.astring.should eq "thirty seven"
    end

    it "loads test profile" do
      builder = Root.new_builder.provider(CrConfig::Providers::FolderProfileConfigProvider.new
        .folder("spec/test_files/folder_profile_spec")
        .base_file("config.yml")
        .profiles { ["test"] }
      )

      root = builder.build

      root.server.host.should eq "server"
      root.server.port.should eq 1234
      root.database.host.should eq "the real host"
      root.database.username.should eq "test_user"
      root.database.password.should eq "test_password"
      root.misc.anumber.should eq 12
      root.misc.astring.should eq "thirty seven"
    end

    it "loads local profile" do
      builder = Root.new_builder.provider(CrConfig::Providers::FolderProfileConfigProvider.new
        .folder("spec/test_files/folder_profile_spec")
        .base_file("config.yml")
        .profiles { ["local"] }
      )

      root = builder.build

      root.server.host.should eq "server"
      root.server.port.should eq 4321
      root.database.host.should eq "localhost"
      root.database.username.should eq "local user"
      root.database.password.should eq "cleartext password"
      root.misc.anumber.should eq 37
      root.misc.astring.should eq "thirty seven"
    end

    it "loads test and local profiles" do
      builder = Root.new_builder.provider(CrConfig::Providers::FolderProfileConfigProvider.new
        .folder("spec/test_files/folder_profile_spec")
        .base_file("config.yml")
        .profiles { ["test", "local"] }
      )

      root = builder.build

      root.server.host.should eq "server"
      root.server.port.should eq 4321
      root.database.host.should eq "localhost"
      root.database.username.should eq "local user"
      root.database.password.should eq "test_password"
      root.misc.anumber.should eq 12
      root.misc.astring.should eq "thirty seven"
    end

    it "loads local and test profiles" do
      builder = Root.new_builder.provider(CrConfig::Providers::FolderProfileConfigProvider.new
        .folder("spec/test_files/folder_profile_spec")
        .base_file("config.yml")
        .profiles { ["local", "test"] }
      )

      root = builder.build

      root.server.host.should eq "server"
      root.server.port.should eq 4321
      root.database.host.should eq "localhost"
      root.database.username.should eq "test_user"
      root.database.password.should eq "test_password"
      root.misc.anumber.should eq 12
      root.misc.astring.should eq "thirty seven"
    end
  end
end
