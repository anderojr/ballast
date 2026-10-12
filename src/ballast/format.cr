module Ballast
  # Formatting and parsing numbers in Brazilian standard
  #
  # Does not depend on system locale (pt_BR.UTF-8 is not
  # always installed), so the result is the same on any
  # machine
  module Format
    extend self

    # Symbols for all currencies, from biggest to shortest
    CURRENCY_SYMBOLS = Currency.values.map(&.symbol).sort_by! { |symbol| -symbol.size }

    # money(1234.5) -> "R$ 1.234,50"
    def money(value : Number, currency : Currency = Currency::BRL, places : Int32 = 2) : String
      sign = value < 0 ? "-" : ""
      "#{sign}#{currency.symbol} #{number(value.abs, places)}"
    end

    def number(value : Number, places : Int32 = 2) : String
      value.format(separator: ",", delimiter: ".", decimal_places: places)
    end

    # Price with the decimal places it has, between 2 and 6:
    # exchange rate appear as 5,3412 and ETF as 776,60
    def price(value : BigDecimal) : String
      number(value, value.scale.clamp(2, 6).to_i)
    end

    def price(value : BigDecimal, currency : Currency) : String
      "#{currency.symbol} #{price(value)}"
    end

    # Number of shares: integer when it is an integer,
    # otherwise up to 8 decimal places
    def quantity(value : BigDecimal) : String
      places = value.integer? ? 0 : 8
      value.format(separator: ",", delimiter: ".", decimal_places: places, only_significant: true)
    end

    # Value for a table column: symbol on left, number on right
    # so that commas and symbols align across rows
    #
    # column(512.30, 14) -> "R$     512,30"
    def money_column(value : Number, width : Int32, currency : Currency = Currency::BRL, places : Int32 = 2) : String
      symbol = currency.symbol.rjust(3)
      "#{symbol} #{number(value, places).rjust(width - 4)}"
    end

    # percent(0.1598) -> "16,0%"
    def percent(fraction : Number, places : Int32 = 1) : String
      "#{number(fraction * 100, places)}%"
    end

    # Difference in percentage points, always with a sign: "+0.4 p.p."
    def points(fraction : Number) : String
      sign = fraction < 0 ? "−" : "+"
      "#{sign}#{number((fraction * 100).abs, 1)} p.p."
    end

    # Parse a value entered by the user. Accepts both formatting styles:
    #
    # parse_amount?("1.500,50") # => 1500.5
    # parse_amount?("1500.50")  # => 1500.5
    # parse_amount?("R$ 1.500") # => 1500
    # parse_amount?("abc")      # => nil
    def parse_amount?(text : String) : BigDecimal?
      s = text.strip
      CURRENCY_SYMBOLS.each { |symbol| s = s.lchop(symbol) }
      s = s.delete(" _")
      return if s.empty?

      s = if s.includes?(',')
            s.delete('.').tr(",", ".") # 1.234,56
          elsif s.matches?(/\A\d{1,3}(\.\d{3})+\z/)
            s.delete('.') # 1.500 (thousands separator in BR format)
          else
            s # 1234.56
          end

      BigDecimal.new(s) if s.matches?(/\A\d+(\.\d+)?\z/)
    end
  end
end
