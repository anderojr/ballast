module Ballast
  enum Currency
    BRL
    USD

    def symbol : String
      case self
      in .brl? then "R$"
      in .usd? then "US$"
      end
    end
  end
end
