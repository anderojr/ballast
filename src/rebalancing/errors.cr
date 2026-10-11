module Rebalancing
  # Source of all "expected" errors: CLI shows the message
  # and exits withou stacktrace. Every other exception is a bug
  class Error < Exception
  end

  # Problem on wallet.yml. Collects all problems found to
  # display them all at once, rather than one per execution
  class ConfigError < Error
    getter problems : Array(String)

    def initialize(@problems : Array(String))
      super(@problems.join("\n"))
    end

    def self.new(problem : String)
      new([problem])
    end
  end

  # Quote source failed to respond. Message is brief and goes straight
  # to terminal ("timeout", "key refused"...)
  class QuoteUnavailableError < Error
  end

  # Special case: source requires a key but it hasn't been configured.
  # Separated so terminal can explain how to solve it.
  class MissingApiKeyError < QuoteUnavailableError
  end

  # Invalid CLI option
  class UsageError < Error
  end

  # User exited execution (Ctrl+D) at middle of input
  class CancelledError < Error
  end
end
