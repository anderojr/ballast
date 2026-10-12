require "spec"
require "../src/ballast"

def dec(value : String | Int32) : BigDecimal
  BigDecimal.new(value)
end

PORTFOLIO_YML = <<-YAML
  usd_rate: 5.20
  assets:
    IVV:
      quantity: 0.50127394
      currency: USD
      price: 776.60
    VT:
      quantity: 1.05
      currency: USD
      price: 161.54
    VWRA11:
      quantity: 80
      currency: BRL
      price: 116.61
      residual: true
    B5P211:
      quantity: 20
      currency: BRL
      price: 110.12
      target: 16%
  YAML

def sample_portfolio : Ballast::Portfolio
  Ballast::Config.from_yaml(PORTFOLIO_YML).to_portfolio
end

# The same prices as portfolio.yml, as if they had come from the sources
def sample_prices(usd_rate = "5.20", **overrides) : Ballast::Prices
  base = {"IVV" => "776.60", "VT" => "161.54", "VWRA11" => "116.61", "B5P211" => "110.12"}
  overrides.each { |ticker, price| base[ticker.to_s] = price }
  Ballast::Prices.new(
    Ballast::Quote.new(dec(usd_rate), Ballast::Origin::AwesomeAPI),
    base.transform_values { |price| Ballast::Quote.new(dec(price), Ballast::Origin::Typed) },
  )
end
