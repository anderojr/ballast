module Ballast
  # Fires the lookups in fibers and collects the answers through a channel
  #
  # Two steps on purpose: `start` returns right away, and the CLI uses that
  # time to ask for the contribution and the B3 prices. Since a terminal's
  # STDIN is read without blocking the thread, the requests move along while
  # you type, and by the time `wait` is called they've usually arrived.
  #
  # Nothing is raised from here: each request becomes a `Quote` or a
  # `QuoteUnavailableError`, and the caller decides what to do with failures.
  class Quoter
    alias Result = Quote | QuoteUnavailableError

    record Request, key : String, source : Sources::Source, symbol : String

    def initialize(@deadline : Time::Span = 12.seconds)
    end

    def start(requests : Array(Request)) : Batch
      Batch.new(requests, @deadline)
    end

    # Shortcut for when there's nothing to do while waiting.
    def fetch(requests : Array(Request)) : Hash(String, Result)
      start(requests).wait
    end

    class Batch
      @results = {} of String => Result

      def initialize(@requests : Array(Request), deadline : Time::Span)
        @ends_at = Time.instant + deadline
        # Buffer of the exact size: a late fiber that answers after the
        # deadline can still `send` and finish, with nobody listening.
        @channel = Channel({String, Result}).new(@requests.size)

        @requests.each do |request|
          spawn(name: "quote:#{request.key}") do
            @channel.send({request.key, lookup(request)})
          end
        end
      end

      def pending? : Bool
        @results.size < @requests.size
      end

      # Blocks until everyone answers or the deadline passes. Can be called
      # more than once: after the first, it just returns what it has.
      def wait : Hash(String, Result)
        while pending?
          remaining = @ends_at - Time.instant
          break unless remaining.positive?

          select
          when answer = @channel.receive
            key, result = answer
            @results[key] = result
          when timeout(remaining)
            break
          end
        end

        @requests.each do |request|
          @results[request.key] ||= QuoteUnavailableError.new("timed out")
        end
        @results
      end

      private def lookup(request : Request) : Result
        request.source.quote(request.symbol)
      rescue ex : QuoteUnavailableError
        ex
      rescue ex
        QuoteUnavailableError.new("unexpected error: #{ex.message}")
      end
    end
  end
end
