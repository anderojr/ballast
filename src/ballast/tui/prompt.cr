module Ballast
  module TUI
    # Asks for amounts in the terminal. Takes the IOs in the constructor so
    # it can be tested with `IO::Memory`
    class Prompt
      def initialize(@input : IO = STDIN, @output : IO = STDOUT)
      end

      # Asks for a positive amount. With *suggestion*, an empty Enter takes it
      # Repeats until it gets something valid. Ctrl+D raises `CancelledError`
      def amount(label : String, currency : Currency, suggestion : BigDecimal? = nil, indent : Int32 = 3) : BigDecimal
        loop do
          @output << " " * indent << label << Style.muted(currency.symbol)
          @output << " " << Style.muted("[#{Format.price(suggestion)}]") if suggestion
          @output << Style.title(" › ")
          @output.flush

          line = @input.gets
          raise CancelledError.new("input closed") unless line
          # Without a TTY (input from a pipe) the user's Enter doesn't show
          # on screen. Break the line here so the rest doesn't stick to it
          @output.puts unless @input.tty?

          return suggestion if suggestion && line.blank?
          if (value = Format.parse_amount?(line)) && value > 0
            return value
          end
          @output << " " * (indent + 2) << Style.error("✖ ") << "couldn't read #{line.strip.inspect}; "
          @output << Style.muted("try something like 1.234,56") << '\n'
        end
      end
    end
  end
end
