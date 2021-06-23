module CrCfgV2
  abstract class AbstractBuilder
    abstract def build

    abstract def properties : Hash(String, String)
  end

  abstract class AbstractProvider
    abstract def populate(bob : AbstractBuilder)
  end
end
