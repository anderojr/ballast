module Ballast
  # Where a price came from. Shown in the terminal next to each quote.
  enum Origin
    AwesomeAPI
    Finnhub
    Typed
    PortfolioFile

    def online? : Bool
      awesome_api? || finnhub?
    end

    def label : String
      case self
      in .awesome_api?    then "AwesomeAPI"
      in .finnhub?        then "Finnhub"
      in .typed?          then "typed"
      in .portfolio_file? then "portfolio.yml"
      end
    end
  end

  # A price and where it came from. failure keeps why the online source
  # wasn't used, when that's the case, so the report can warn about it
  record Quote,
    value : BigDecimal,
    origin : Origin,
    time : Time? = nil,
    failure : String? = nil

  # Every price of the day, already resolved (online, typed or fallback)
  record Prices, usd_rate : Quote?, assets : Hash(String, Quote) do
    def [](asset : Asset) : Quote
      assets[asset.ticker]
    end

    # Price of one share in BRL
    def in_brl(asset : Asset) : BigDecimal
      price = self[asset].value
      case asset.currency
      in .brl? then price
      in .usd? then price * (usd_rate || raise Error.new("no USD/BRL rate")).value
      end
    end

    # Quotes that fell back to the file because the online source failed
    def failed : Array({String, Quote})
      all = assets.to_a
      usd_rate.try { |quote| all.unshift({"USD/BRL", quote}) }
      all.select { |_, quote| quote.failue }
    end
  end
end
