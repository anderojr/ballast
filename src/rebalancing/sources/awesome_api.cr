module Rebalancing
  module Sources
    # Exchange rate to BRL from AwesomeAPI. Free, no key.
    #
    # `GET /json/last/USD-BRL` →
    # `{"USDBRL": {"bid": "5.3412", "timestamp": "1759420620", ...}}`
    class AwesomeAPI < Http
      URL = "https://economia.awesomeapi.com.br/json/last/%s-BRL"

      # Only the fields we care about. The numbers come as strings
      # `big/json` turns them straight into BigDecimal, no Float involved
      struct Pair
        include JSON::Serializable
        getter bid : BigDecimal
        getter timestamp : String
      end

      def name : String
        "AwesomeAPI"
      end

      # *symbol* is the source currency: `"USD"`
      def quote(symbol : String) : Quote
        response = get(URL % symbol)
        case response.status_code
        when 200 then self.class.parse(response.body, symbol)
        when 404 then raise QuoteUnavailableError.new("pair #{symbol}-BRL doesn't exist")
        else          unexpected_status(response)
        end
      end

      def self.parse(json : String, symbol : String) : Quote
        pair = Hash(String, Pair).from_json(json)["#{symbol}BRL"]?
        raise QuoteUnavailableError.new("response has no #{symbol}BRL") unless pair
        raise QuoteUnavailableError.new("rate came back as zero") unless pair.bid > 0

        Quote.new(pair.bid, Origin::AwesomeAPI, time: Time.unix(pair.timestamp.to_i64))
      rescue JSON::ParseException | InvalidBigDecimalException | ArgumentError
        raise QuoteUnavailableError.new("unexpected response format")
      end
    end
  end
end
