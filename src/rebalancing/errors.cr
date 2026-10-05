module Rebalancing
  # Source of all "expected" errors: CLI shows the message
  # and exits withou stacktrace. Every other exception is a bug
  class Error < Exception
  end

  # Issue on wallet.yml. Collects all issues found to
  # display them all at once, rather than one per execution
  class ConfigError < Error
    getter issues : Array(String)

    def initialize(@issues : Array(String))
      super(@issues.join("\n"))
    end

    def self.new(issue : String)
      new([issue])
    end
  end

  # Quote source failed to respond. Message is brief and goes straight
  # to terminal ("timeout", "key refused"...)
  class QuoteUnavailableError < Error
  end

  # Special case: source requires a key but it hasn't been configured.
  # Separated so terminal can explain how to solve it.
  class MissingApiKeyError < Error
  end

  # Invalid CLI option
  class UsageError < Error
  end

  # User exited execution (Ctrl+D) at middle of input
  class CancelledError
  end
end
