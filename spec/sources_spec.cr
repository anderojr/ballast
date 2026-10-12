require "./spec_helper"

# Real responses copied from the APIs' docs
AWESOME_JSON = <<-JSON
  {"USDBRL":{"code":"USD","codein":"BRL","name":"Dólar Americano/Real Brasileiro",
  "high":"5.734","low":"5.7279","varBid":"-0.0054","pctChange":"-0.09",
  "bid":"5.7276","ask":"5.7282","timestamp":"1618315045","create_date":"2021-04-13 08:57:27"}}
  JSON

FINNHUB_JSON = %({"c":776.6,"d":1.2,"dp":0.15,"h":778.1,"l":772.9,"o":774,"pc":775.4,"t":1759348800})

describe Rebalancing::Sources::AwesomeAPI do
  it "reads the bid as an exact BigDecimal, plus the time" do
    quote = Rebalancing::Sources::AwesomeAPI.parse(AWESOME_JSON, "USD")
    quote.value.should eq dec("5.7276")
    quote.origin.awesome_api?.should be_true
    quote.time.should eq Time.unix(1618315045)
  end

  it "explains when the pair isn't in the response" do
    expect_raises(Rebalancing::QuoteUnavailableError, "response has no EURBRL") do
      Rebalancing::Sources::AwesomeAPI.parse(AWESOME_JSON, "EUR")
    end
  end

  it "doesn't let broken JSON escape as a generic exception" do
    expect_raises(Rebalancing::QuoteUnavailableError, "unexpected response format") do
      Rebalancing::Sources::AwesomeAPI.parse(%({"status":404,"code":"CoinNotExists"}), "USD")
    end
    expect_raises(Rebalancing::QuoteUnavailableError, "unexpected response format") do
      Rebalancing::Sources::AwesomeAPI.parse("<html>", "USD")
    end
  end
end

describe Rebalancing::Sources::Finnhub do
  it "reads the current price without going through Float" do
    quote = Rebalancing::Sources::Finnhub.parse(FINNHUB_JSON, "IVV")
    quote.value.should eq dec("776.6")
    quote.time.should eq Time.unix(1759348800)
  end

  it "treats a zeroed response as an unknown symbol" do
    zeroed = %({"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0})
    expect_raises(Rebalancing::QuoteUnavailableError, "symbol XYZ not found") do
      Rebalancing::Sources::Finnhub.parse(zeroed, "XYZ")
    end
  end

  it "fails without touching the network when there's no key" do
    expect_raises(Rebalancing::MissingApiKeyError, "FINNHUB_API_KEY is not set") do
      Rebalancing::Sources::Finnhub.new(nil).quote("IVV")
    end
  end
end
