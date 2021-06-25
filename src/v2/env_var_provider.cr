module CrCfgV2
  class EnvVarProvider < AbstractProvider
    def populate(bob : AbstractBuilder)
      ENV.each do |env_name, env_val|
        name = env_name.downcase.gsub(/_/, '.')
        bob.set(name, env_val)
      end
    end
  end
end
