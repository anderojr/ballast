module Ballast
  module Sources
    # Quotes for US assets (stocks and ETFs) from Finnhub.
    #
    # Free plan: needs a key (sign-up without a card), 60 req/min.
    # The key goes in the `X-Finnhub-Token` header, not in the URL, so it
    # doesn't show up in proxy logs.
    #
    # `GET /api/v1/quote?symbol=IVV` → `{"c": 776.6, "t": 1759348800, ...}`
    # An unknown symbol isn't a 404: everything comes back zeroed.
    class Finnhub < Http
      URL     = "https://finnhub.io/api/v1/quote?symbol=%s"
      ENV_VAR = "FINNHUB_API_KEY"

      # The JSON body. Not called `Quote` so it doesn't shadow
      # `Ballast::Quote` inside this class
      struct Payload
        include JSON::Serializable
        # Current price (or last close, when the market is closed)
        getter c : BigDecimal
        # Unix time of the last trade
        getter t : Int64?
      end

      def initialize(@token : String?)
      end

      def self.from_env : self
        new(ENV[ENV_VAR]?.presence)
      end

      def name : String
        "Finnhub"
      end

      def quote(symbol : String) : Quote
        token = @token || raise MissingApiKeyError.new("#{ENV_VAR} is not set")

        response = get(URL % URI.encode_path_segment(symbol), HTTP::Headers{"X-Finnhub-Token" => token})
        case response.status_code
        when 200 then self.class.parse(response.body, symbol)
        when 401 then raise QuoteUnavailableError.new("key rejected (check #{ENV_VAR})")
        when 403 then raise QuoteUnavailableError.new("no access to #{symbol} on the free plan")
        when 429 then raise QuoteUnavailableError.new("hit the 60 req/min limit")
        else          unexpected_status(response)
        end
      end

      def self.parse(json : String, symbol : String) : Quote
        payload = Payload.from_json(json)
        raise QuoteUnavailableError.new("symbol #{symbol} not found") unless payload.c > 0

        time = payload.t.try { |unix| Time.unix(unix) if unix > 0 }
        Quote.new(payload.c, Origin::Finnhub, time: time)
      rescue JSON::ParseException | JSON::SerializableError | InvalidBigDecimalException
        raise QuoteUnavailableError.new("unexpected response format")
      end
    end
  end
end
