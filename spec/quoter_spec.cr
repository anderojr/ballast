require "./spec_helper"

private def request(key : String, source : Ballast::Sources::Source) : Ballast::Quoter::Request
  Ballast::Quoter::Request.new(key, source, key)
end

describe Ballast::Quoter do
  it "returns quotes and failures side by side, without raising" do
    source = Ballast::FakeSource.new({"IVV" => dec("776.6"), "VT" => "rate limit reached"} of String => BigDecimal | String)
    results = Ballast::Quoter.new.fetch([request("IVV", source), request("VT", source)])

    results["IVV"].as(Ballast::Quote).value.should eq dec("776.6")
    results["VT"].as(Ballast::QuoteUnavailableError).message.should eq "rate limit reached"
  end

  it "fetches in parallel" do
    slow = Ballast::FakeSource.new({"A" => dec(1), "B" => dec(2), "C" => dec(3)} of String => BigDecimal | String, delay: 200.milliseconds)
    started = Time.instant
    Ballast::Quoter.new.fetch(%w[A B C].map { |symbol| request(symbol, slow) })
    (Time.instant - started).should be < 450.milliseconds
  end

  it "marks whoever misses the deadline as timed out" do
    fast = Ballast::FakeSource.new({"A" => dec(1)} of String => BigDecimal | String)
    slow = Ballast::FakeSource.new({"B" => dec(2)} of String => BigDecimal | String, delay: 2.seconds)

    results = Ballast::Quoter.new(deadline: 100.milliseconds).fetch([request("A", fast), request("B", slow)])
    results["A"].should be_a Ballast::Quote
    results["B"].as(Ballast::QuoteUnavailableError).message.should eq "timed out"
  end

  it "treats an unexpected exception from the source as unavailable" do
    broken = Ballast::FakeSource.new({} of String => BigDecimal | String)
    results = Ballast::Quoter.new.fetch([request("X", broken)])
    results["X"].should be_a Ballast::QuoteUnavailableError
  end

  it "lets you work while the lookups are running" do
    slow = Ballast::FakeSource.new({"A" => dec(1)} of String => BigDecimal | String, delay: 100.milliseconds)
    batch = Ballast::Quoter.new.start([request("A", slow)])
    batch.pending?.should be_true
    sleep 150.milliseconds # "user typing"
    started = Time.instant
    batch.wait["A"].should be_a Ballast::Quote
    (Time.instant - started).should be < 20.milliseconds
  end
end
