module Rebalancing
  # Where an asset's price comes from at run time.
  enum PriceSource
    # Typed in the terminal (B3: the broker is real-time, the free APIs are not).
    Manual
    # Fetched from Finnhub.
    Finnhub
  end

  # A position in the portfolio. Immutable: the purchase plan never changes
  # the asset, it only works out how much of it to buy.
  record Asset,
    ticker : String,
    quantity : BigDecimal,
    currency : Currency,
    allocation : Allocation::Kind,
    price_source : PriceSource,
    # Last known price (from the YAML). Suggested when asking for manual
    # prices and used as a fallback when Finnhub doesn't answer.
    last_known_price : BigDecimal? do
    def target_fraction : BigDecimal?
      allocation.as?(Allocation::Target).try(&.fraction)
    end

    def residual? : Bool
      allocation.is_a?(Allocation::Residual)
    end
  end
end
