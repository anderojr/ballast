require "./spec_helper"

private def problems(yaml : String) : Array(String)
  Ballast::Config.from_yaml(yaml).to_portfolio
  [] of String
rescue ex : Ballast::ConfigError
  ex.problems
end

private def asset(extra : String, currency = "BRL") : String
  <<-YAML
    assets:
      A:
        quantity: 1
        currency: #{currency}
        price: 10
        #{extra}
      R:
        quantity: 1
        currency: BRL
        residual: true
    YAML
end

describe Ballast::Config do
  it "builds the portfolio in file order, with the right roles" do
    portfolio = sample_portfolio
    portfolio.assets.map(&.ticker).should eq %w[IVV VT VWRA11 B5P211]
    portfolio["IVV"].allocation.should be_a Ballast::Allocation::Hold
    portfolio["VWRA11"].residual?.should be_true
    portfolio["B5P211"].target_fraction.should eq dec("0.16")
    portfolio["IVV"].quantity.should eq dec("0.50127394")
    portfolio.last_known_usd_rate.should eq dec("5.20")
  end

  it "picks the price source from the currency when `price_source` is omitted" do
    portfolio = sample_portfolio
    portfolio.priced_by(:finnhub).map(&.ticker).should eq %w[IVV VT]
    portfolio.priced_by(:manual).map(&.ticker).should eq %w[VWRA11 B5P211]
  end

  it "accepts target as a fraction" do
    problems(asset("target: 0.16")).should be_empty
    Ballast::Config.from_yaml(asset("target: 0.16")).to_portfolio["A"].target_fraction.should eq dec("0.16")
  end

  it "accepts `price_source: manual` on a USD asset" do
    portfolio = Ballast::Config.from_yaml(asset("price_source: manual", currency: "USD")).to_portfolio
    portfolio["A"].price_source.manual?.should be_true
  end

  it "requires exactly one residual" do
    none = "assets:\n  A:\n    quantity: 1\n    currency: BRL\n"
    problems(none).first.should contain "residual: true"

    two = asset("residual: true")
    problems(two).first.should contain "there can be only one residual asset (found A, R)"
  end

  it "doesn't allow target and residual on the same asset" do
    problems(asset("target: 10%\n    residual: true")).should contain "A: pick `target` or `residual`, not both"
  end

  it "validates value ranges" do
    problems(asset("target: 120%")).should contain "A: target must be between 0% and 100%"
    problems(asset("price_source: finnhub")).should contain "A: Finnhub (free plan) only quotes USD assets"
  end

  it "complains when targets add up to more than 100%" do
    yaml = <<-YAML
      assets:
        A: {quantity: 1, currency: BRL, target: 60%}
        B: {quantity: 1, currency: BRL, target: 50%}
        R: {quantity: 1, currency: BRL, residual: true}
      YAML
    problems(yaml).should contain "targets add up to more than 100% (110,0%)"
  end

  it "gathers every problem into a single exception" do
    yaml = <<-YAML
      assets:
        A: {quantity: -1, currency: BRL, target: 2}
      YAML
    problems(yaml).should eq [
      "A: quantity can't be negative",
      "A: target must be between 0% and 100%",
      "mark one asset with `residual: true` (it receives what's left of the contribution)",
      "targets add up to more than 100% (200,0%)",
    ]
  end

  it "rejects unknown keys (catches typos)" do
    expect_raises(YAML::ParseException, /targets/) do
      Ballast::Config.from_yaml(asset("targets: 16%"))
    end
  end

  it "rejects badly formatted numbers" do
    expect_raises(YAML::ParseException, /expected a number/) do
      Ballast::Config.from_yaml(asset("").sub("price: 10", "price: 10,5"))
    end
  end

  it "turns a missing file into ConfigError" do
    expect_raises(Ballast::ConfigError, /not found/) do
      Ballast::Config.load(Path["/does/not/exist.yml"])
    end
  end
end
