module CrCfgV2
  abstract class AbstractBuilder
    abstract def build

    abstract def set(name : String, val : AllTypes)
  end

  abstract class AbstractProvider
    abstract def populate(bob : AbstractBuilder)
  end
end
