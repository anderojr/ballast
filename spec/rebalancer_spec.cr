require "./spec_helper"

private def plan(amount : String, portfolio = sample_portfolio, prices = sample_prices) : Ballast::Plan
  Ballast::Rebalancer.new(portfolio, prices).plan(dec(amount))
end

private def shares(plan : Ballast::Plan) : Hash(String, Int32)
  plan.positions.to_h { |position| {position.asset.ticker, position.shares} }
end

describe Ballast::Rebalancer do
  it "matches the expected result" do
    result = plan("1500")
    shares(result).should eq({"IVV" => 0, "VT" => 0, "VWRA11" => 10, "B5P211" => 3})
    result.leftover.should eq dec("3.54")
    result.invested.should eq dec("1496.46")
  end

  it "converts USD at the exchange rate" do
    result = plan("1500")
    ivv = result.positions.find! { |position| position.asset.ticker == "IVV" }
    ivv.before.should eq dec("0.50127394") * dec("776.60") * dec("5.20")
  end

  it "rounds the target to the nearest integer, even if it overshoots a little" do
    # contribution 1000: 0,16 × 15.437,51 − 2.202,40 = 267,60 → 267,60 / 110,12 = 2,43 → 2
    # contribution 1100: 0,16 × 15.537,51 − 2.202,40 = 283,60 → 283,60 / 110,12 = 2,58 → 3
    shares(plan("1100"))["B5P211"].should eq 3
    shares(plan("1000"))["B5P211"].should eq 2
  end

  it "never spends more than the contribution because of rounding" do
    # Gap bigger than the contribution; round(100 / 110,12) = 1, but one
    # share costs more than the R$ 100 available.
    result = plan("100")
    shares(result)["B5P211"].should eq 0
    result.leftover.should eq dec("100")
    result.leftover.should be >= 0
  end

  it "sends everything to the residual when the target is already met" do
    prices = sample_prices(B5P211: "300")
    result = plan("1500", prices: prices)
    result.positions.find!(&.asset.target_fraction).gap.should eq 0
    shares(result)["B5P211"].should eq 0
    shares(result)["VWRA11"].should eq (dec("1500") / dec("116.61")).floor.to_i
  end

  it "gives the target priority when the contribution doesn't close the gap" do
    # contribution 120: gap = 0,16 × 14.557,51 − 2.202,40 = 126,80 > 120.
    # The whole contribution becomes the target's budget: round(120 / 110,12) = 1 share,
    # and the R$ 9,88 left don't pay for one share of the residual.
    result = plan("120")
    shares(result)["B5P211"].should eq 1
    shares(result)["VWRA11"].should eq 0
    result.leftover.should eq dec("9.88")
  end

  it "splits proportionally between several targets when the contribution isn't enough" do
    yaml = <<-YAML
      assets:
        A: {quantity: 0, currency: BRL, target: 30%}
        B: {quantity: 0, currency: BRL, target: 10%}
        R: {quantity: 100, currency: BRL, residual: true}
      YAML
    portfolio = Ballast::Config.from_yaml(yaml).to_portfolio
    one = Ballast::Quote.new(dec(1), Ballast::Origin::Typed)
    prices = Ballast::Prices.new(nil, {"A" => one, "B" => one, "R" => one})

    # total after contribution 200 → gaps A=60, B=20 (sum 80 ≤ 100): each gets its own
    shares(plan("100", portfolio, prices)).should eq({"A" => 60, "B" => 20, "R" => 20})

    # total after contribution 140 → gaps A=42, B=14 (sum 56 > 40): 3:1 → 30 and 10
    shares(plan("40", portfolio, prices)).should eq({"A" => 30, "B" => 10, "R" => 0})
  end

  it "handles the residual last even if it comes first in the file" do
    # VWRA11 (residual) comes before B5P211 (target) in the sample.
    result = plan("1500")
    shares(result)["B5P211"].should eq 3
  end

  it "rejects a zero contribution" do
    expect_raises(ArgumentError) { plan("0") }
  end

  describe Ballast::Plan do
    it "computes weights that add up to 100%" do
      result = plan("1500")
      result.positions.sum(Ballast::ZERO) { |position| result.weight_after(position) }.round(10).should eq 1
    end

    it "shows how much is still missing to the target after buying" do
      result = plan("1500")
      b5p = result.positions.find!(&.asset.target_fraction)
      missing = result.missing_to_target(b5p) || fail "B5P211 should have a target"
      missing.abs.should be < b5p.price
    end
  end
end
