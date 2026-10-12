module Ballast
  # The validated portfolio. This is what the rest of the program sees
  # The file format stays isolated in Config
  record Portfolio, assets : Array(Asset), last_known_usd_rate : BigDecimal? do
    def holds_usd? : Bool
      assets.any?(&.currency.usd?)
    end

    def priced_by(source : PriceSource) : Array(Asset)
      assets.select { |asset| asset.price_source == source }
    end

    def [](ticker : String) : Asset
      assets.find { |asset| asset.ticker == ticker } || raise KeyError.new("#{ticker} is not in the portfolio")
    end
  end
end
