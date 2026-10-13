require "option_parser"

module Ballast
  # Runs one execution: reads options, loads the portfolio, gathers prices
  # (online + typed), does the math and draws it
  #
  # The IOs and quote sources come in through the constructor; the specs pass
  # `IO::Memory` and fake sources and run the whole flow without network
  class CLI
    include TUI::Style

    record Options,
      config : Path? = nil,
      amount : BigDecimal? = nil,
      ask : Bool = true,
      offline : Bool = false

    # A quote that comes from the internet, plus what to use if it fails
    private record Online, key : String, currency : Currency, fallback : BigDecimal?, source : Sources::Source do
      def request : Quoter::Request
        Quoter::Request.new(key, source, key == USD_BRL ? "USD" : key)
      end
    end

    USD_BRL = "USD/BRL"

    def initialize(@input : IO = STDIN,
                   @output : IO = STDOUT,
                   @errors : IO = STDERR,
                   @fx_source : Sources::Source = Sources::AwesomeAPI.new,
                   @foreign_source : Sources::Source = Sources::Finnhub.from_env,
                   @quoter : Quoter = Quoter.new)
      @prompt = TUI::Prompt.new(@input, @output)
    end

    # Returns the exit code: 0 ok, 1 runtime error, 2 invalid usage/config,
    # 130 cancelled by the user
    def run(argv : Array(String)) : Int32
      if options = parse(argv)
        execute(options)
      end
      0
    rescue ex : UsageError
      failure(ex.message, "ballast --help lists the options")
      2
    rescue ex : ConfigError
      @errors.puts
      @errors << " " << error("✖ ") << strong("invalid portfolio") << '\n'
      ex.problems.each { |problem| @errors << "   " << muted("•") << " " << problem << '\n' }
      2
    rescue CancelledError
      @output.puts
      @output.puts muted("   cancelled.")
      130
    rescue ex : Error
      failure(ex.message)
      1
    end

    private def parse(argv : Array(String)) : Options?
      options = Options.new
      done = false

      OptionParser.parse(argv) do |parser|
        parser.banner = "usage: ballast [options]\n\nWorks out how to split this month's contribution across the portfolio.\n"

        parser.on("-a AMOUNT", "--amount=AMOUNT", "contribution in R$ (e.g., 1500 or 1.500,00); asks if omitted") do |value|
          amount = Format.parse_amount?(value)
          raise UsageError.new("invalid amount: #{value.inspect}") unless amount && amount > 0
          options = options.copy_with(amount: amount)
        end
        parser.on("-c FILE", "--config=FILE", "portfolio file (default: ./portfolio.yml, then ~/.config/ballast/)") do |value|
          options = options.copy_with(config: Path[value])
        end
        parser.on("-y", "--yes", "don't ask for manual prices; use the ones in the file") do
          options = options.copy_with(ask: false)
        end
        parser.on("--offline", "skip the APIs; use the prices in the file") do
          options = options.copy_with(offline: true)
        end
        parser.on("--no-color", "turn colors off") { Colorize.enabled = false }
        parser.on("-v", "--version", "show the version") do
          @output.puts "ballast #{VERSION}"
          done = true
        end
        parser.on("-h", "--help", "show this help") do
          @output.puts parser
          done = true
        end

        parser.separator <<-TXT

          Environment:
              FINNHUB_API_KEY                  free key from https://finnhub.io (quotes for USD assets)
              NO_COLOR                         turns colors off
          TXT

        parser.invalid_option { |flag| raise UsageError.new("unknown option: #{flag}") }
        parser.missing_option { |flag| raise UsageError.new("#{flag} needs a value") }
        parser.unknown_args do |before, after|
          if arg = (before + after).first?
            raise UsageError.new(arg.starts_with?('-') ? "unknown option: #{arg}" : "unexpected argument: #{arg}")
          end
        end
      end

      done ? nil : options
    end

    private def execute(options : Options) : Nil
      path = options.config || Config.locate ||
             raise ConfigError.new("couldn't find portfolio.yml in the current folder or in ~/.config/ballast/ (use --config)")
      portfolio = Config.load(path)

      box(@output, "◆ ballast #{VERSION}", "#{path.basename} · #{Time.local.to_s("%d/%m/%Y %H:%M")}")

      online = online_quotes_for(portfolio)
      # Fire them now: the requests move along while the user types.
      batch = @quoter.start(online.map(&.request)) unless options.offline || online.empty?

      amount, typed = this_month(portfolio, options)
      resolved = quotes(online, batch, options)

      prices = Prices.new(resolved.delete(USD_BRL), typed.merge(resolved))
      plan = Rebalancer.new(portfolio, prices).plan(amount)
      TUI::Report.new(@output, plan, prices).draw
    end

    private def online_quotes_for(portfolio : Portfolio) : Array(Online)
      list = [] of Online
      list << Online.new(USD_BRL, Currency::BRL, portfolio.last_known_usd_rate, @fx_source) if portfolio.holds_usd?
      portfolio.priced_by(:finnhub).each do |asset|
        list << Online.new(asset.ticker, asset.currency, asset.last_known_price, @foreign_source)
      end
      list
    end

    # Contribution and manual prices (B3). With `-y`, just echoes the file's
    private def this_month(portfolio : Portfolio, options : Options) : {BigDecimal, Hash(String, Quote)}
      manual = portfolio.priced_by(:manual)
      will_ask = options.ask && manual.any?(&.last_known_price)
      section(@output, "THIS MONTH", will_ask ? "Enter keeps the [value]" : nil)

      width = (manual.map(&.ticker.size) << "amount".size).max + 2

      amount = if value = options.amount
                 echo("amount", Currency::BRL, value, width)
                 value
               else
                 @prompt.amount(left("amount", width), Currency::BRL)
               end
      prices = manual.to_h do |asset|
        suggestion = asset.last_known_price
        quote = if options.ask || suggestion.nil?
                  Quote.new(@prompt.amount(left(asset.ticker, width), asset.currency, suggestion), Origin::Typed)
                else
                  echo(asset.ticker, asset.currency, suggestion, width)
                  Quote.new(suggestion, Origin::PortfolioFile)
                end
        {asset.ticker, quote}
      end
      {amount, prices}
    end

    private def echo(label : String, currency : Currency, value : BigDecimal, width : Int32) : Nil
      @output << "   " << left(label, width) << muted(currency.symbol) << " " << strong(Format.price(value)) << '\n'
    end

    private def quotes(online : Array(Online), batch : Quoter::Batch?, options : Options) : Hash(String, Quote)
      return {} of String => Quote if online.empty?

      section(@output, "QUOTES", options.offline ? "offline mode" : nil)

      results = if batch.nil?
                  online.to_h { |item| {item.key, QuoteUnavailableError.new("offline mode").as(Quoter::Result)} }
                elsif batch.pending?
                  TUI::Spinner.spin(@output, "fetching #{online.map(&.source.name).uniq!.join(" and ")}…") { batch.wait }
                else
                  batch.wait
                end

      width = online.max_of(&.key.size) + 2
      missing_key = false

      quoted = online.to_h do |item|
        quote = case result = results[item.key]
                in Quote
                  quote_line(item, result, width)
                  result
                in QuoteUnavailableError
                  missing_key ||= result.is_a?(MissingApiKeyError)
                  fallback(item, result, width, options)
                end
        {item.key, quote}
      end

      if missing_key
        @output << "     " << muted("tip: get a free key at finnhub.io and run `export #{Sources::Finnhub::ENV_VAR}=...`") << '\n'
      end
      quoted
    end

    private def quote_line(item : Online, quote : Quote, width : Int32) : Nil
      at = quote.time.try { |time| " · #{time.to_local.to_s("%d/%m %H:%M")}" }
      @output << "   " << ok("✔ ") << strong(left(item.key, width))
      @output << right(Format.price(quote.value, item.currency), 13) << "   " << muted("#{left(quote.origin.label, 10)}#{at}") << '\n'
    end

    # The source failed: warn, then ask for the price (suggesting the file's)
    # or, with `-y`, use the file's right away
    private def fallback(item : Online, problem : QuoteUnavailableError, width : Int32, options : Options) : Quote
      reason = problem.message || "failed"
      # With `-y` and a price in the file, use it without asking
      automatic = options.ask ? nil : item.fallback

      if options.offline && automatic
        @output << "   " << warning("▲ ") << strong(left(item.key, width))
        @output << right(Format.price(automatic, item.currency), 13) << "   " << muted("portfolio.yml (offline)") << '\n'
        return Quote.new(automatic, Origin::PortfolioFile, failure: reason)
      end

      if options.offline
        @output << "   " << warning("▲ ") << strong(left(item.key, width)) << muted("not fetched (--offline)") << '\n'
      else
        @output << "   " << error("✖ ") << strong(left(item.key, width))
        @output << error("#{item.source.name} unavailable") << muted(": #{reason}") << '\n'
      end

      if automatic
        @output << "     " << muted("↳ using #{Format.price(automatic, item.currency)} from portfolio.yml") << '\n'
        Quote.new(automatic, Origin::PortfolioFile, failure: reason)
      else
        value = @prompt.amount(left(item.key, width), item.currency, item.fallback, indent: 5)
        Quote.new(value, Origin::Typed, failure: reason)
      end
    end

    private def failure(message : String?, hint : String? = nil) : Nil
      @errors.puts
      @errors << " " << error("✖ ") << (message || "unknown error") << '\n'
      @errors << "   " << muted(hint) << '\n' if hint
    end
  end
end
