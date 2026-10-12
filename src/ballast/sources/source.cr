require "http/client"

module Ballast
  module Sources
    # Something that knows how to quote a symbol. When it can't, it raises
    # `QuoteUnavailableError` with a short message, ready for the terminal.
    abstract class Source
      abstract def name : String
      abstract def quote(symbol : String) : Quote
    end

    # Base for HTTP sources: timeouts and translation of network errors.
    abstract class Http < Source
      CONNECT_TIMEOUT = 4.seconds
      READ_TIMEOUT    = 6.seconds

      private def get(url : String, headers : HTTP::Headers = HTTP::Headers.new) : HTTP::Client::Response
        uri = URI.parse(url)
        HTTP::Client.new(uri) do |client|
          client.connect_timeout = CONNECT_TIMEOUT
          client.read_timeout = READ_TIMEOUT
          client.get(uri.request_target, headers: headers)
        end
      rescue IO::TimeoutError
        raise QuoteUnavailableError.new("timed out")
      rescue Socket::Addrinfo::Error
        raise QuoteUnavailableError.new("no internet (DNS lookup failed)")
      rescue ex : Socket::Error | IO::Error | OpenSSL::Error
        raise QuoteUnavailableError.new("no connection (#{ex.message})")
      end

      # Default message for HTTP statuses the source doesn't handle in a
      # specific way.
      private def unexpected_status(response : HTTP::Client::Response) : NoReturn
        reason = case response.status_code
                 when 429      then "rate limit reached"
                 when 500..599 then "service is down (HTTP #{response.status_code})"
                 else               "HTTP #{response.status_code}"
                 end
        raise QuoteUnavailableError.new(reason)
      end
    end
  end
end
