module CrCfgV2
  abstract class AbstractBuilder
    abstract def build
  end

  abstract class AbstractProvider
    abstract def populate(bob : AbstractBuilder)
  end
end
