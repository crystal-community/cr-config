module CrCfgV2
  class ProcProvider < AbstractProvider
    def initialize(@proc : Proc(AbstractBuilder, Nil))
    end

    def populate(bob : AbstractBuilder)
      @proc.call(bob)
    end
  end
end
