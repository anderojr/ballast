module Ballast
  module TUI
    # Draws the plan: current portfolio, what to buy and how it ends up
    class Report
      include Style

      BAR_WIDTH = 22
      # Column where the BRL amounts of the purchase section end
      LINE_END = WIDTH - 2
      AMOUNT   = 14

      def initialize(@io : IO, @plan : Plan, @prices : Prices)
      end

      def draw : Nil
        current_portfolio
        purchases
        notes
        after_purchase
        fallbacks_used
        @io.puts
      end

      private def current_portfolio : Nil
        section(@io, "CURRENT PORFOLIO", "total #{Format.money(@plan.total_before)}")
        @io << "   " << muted(left("asset", 0) + left("role", 13) + right("shares", 10) + right("price", 15) + right("value", 15) + right("weight", 7)) << '\n'

        @plan.positions.each do |position|
          asset = position.asset
          @io << "   " << strong(left(asset.ticker, 9)) << role(asset)
          @io << right(Format.quantity(asset.quantity), 10)
          price = @prices[asset].value
          @io << "  " << muted(Format.money_column(price, 13, asset.currency, price.scale.clamp(2, 6).to_i))
          @io << "  " << Format.money_column(position.before, 13)
          @io << right(Format.percent(@plan.weight_before(position)), 7) << '\n'
        end
      end

      private def role(asset : Asset) : Colorize::Object(String)
        case allocation = asset.allocation
        in Allocation::Target   then left("target #{Format.percent(allocation.fraction)}", 13).colorize(:cyan)
        in Allocation::Residual then left("residual", 13).colorize(:magenta)
        in Allocation::Hold     then muted(left("·", 13))
        end
      end

      private def purchases : Nil
        section(@io, "PURCHASES", "contribution #{Format.money(@plan.contribution)}")

        if @plan.purchases.empty?
          @io << "   " << warning("nothing to buy: the contribution doesn't pay for one share of any asset") << '\n'
        end

        # Targets first, residual last: that's the order the decision is made in.
        targets, rest = @plan.purchase.partition { |position| !position.asset.residual? }
        (targets + rest).each do |position|
          # 3 + 2 + 4 + 4 + 3 + 8 + 16 = 40 visible columns before the amount
          @io << "   " << title("▸ ") << "buy " << strong(right(position.shares.to_s, 4)) << " × "
          @io << strong(left(position.asset.ticker, 8))
          @io << muted(left("at #{Format.money(position.price)}", 16))
          @io << " " * (LINE_END - 40 - AMOUNT) << Format.money_column(position.cost, AMOUNT) << '\n'
        end

        @io << " " * (LINE_END - AMOUNT) << muted("─" * AMOUNT) << '\n'
        total_line("invested", Format.money_column(@plan.invested, AMOUNT), highlight: true)
        total_line("left in cash", Format.money_column(@plan.leftover, AMOUNT), highlight: false)
      end

      private def total_line(label : String, amount : String, *, highlight : Bool) : Nil
        @io << right(label, LINE_END - AMOUNT - 2) << "  "
        @io << (highlight ? strong(amount) : muted(amount)) << '\n'
      end

      # Explains the targets that didn't land "on the spot": they were
      # already above, or the contribution wasn't enough to get there.
      private def notes : Nil
        messages = @plan.positions.compact_map do |position|
          target = position.asset.target_fraction || next
          missing = @plan.missing_to_target(position) || next
          ticker = position.asset.ticker

          if position.gap.zero?
            "#{ticker} is already above its #{Format.percent(target)} target. " \
            "Since nothing gets sold, it gets nothing this month."
          elsif missing > position.price
            "The contribution doesn't close #{ticker}'s target: #{Format.money(missing)} still missing. " \
            "The gap closes over the next months."
          end
        end
        return if messages.empty?

        @io.puts
        messages.each { |message| paragraph(message) }
      end

      # Wraps long text into lines of up to WIDTH, indented
      private def paragraph(text : String) : Nil
        lines = [] of String
        current = ""
        text.split(' ').each do |word|
          if current.size + word.size + 1 > WIDTH - 6
            lines << current
            current = word
          else
            current = current.empty? ? word : "#{current} #{word}"
          end
        end
        lines << current

        lines.each_with_index do |line, index|
          @io << "   " << (index.zero? ? warning("● ") : "  ") << line << '\n'
        end
      end

      private def after_purchase : Nil
        section(@io, "AFTER PURCHASE", "total #{Format.money(@plan.total_after)}")
        @io << "   " << muted(left("asset", 9) + right("before", 6) + "     " + right("after", 6)) << '\n'

        @plan.positions.each do |position|
          asset = position.asset
          before = @plan.weight_before(position)
          after = @plan.weight_after(position)

          @io << "   " << strong(left(asset.ticker, 9))
          @io << muted(right(Format.percent(before), 6)) << muted("  →  ")
          @io << strong(right(Format.percent(after), 6)) << "  "
          bar(@io, after, BAR_WIDTH, bar_color(asset), mark: asset.target_fraction)
          @io << "  " << status(position) << '\n'
        end
      end

      private def bar_color(asset : Asset) : Colorize::ColorANSI
        case asset.allocation
        in Allocation::Target   then Colorize::ColorANSI::Cyan
        in Allocation::Residual then Colorize::ColorANSI::Magenta
        in Allocation::Hold     then Colorize::ColorANSI::DarkGray
        end
      end

      # For targets, where the asset ended up relative to it. "On target"
      # means less than one share away, the best you can do without fractions.
      private def status(position : Position) : String
        if (target = position.asset.target_fraction) && (missing = @plan.missing_to_target(position))
          deviation = @plan.weight_after(position) - target
          if missing.abs <= position.price
            ok("✔ on target").to_s
          elsif deviation > 0
            title("▲ #{Format.points(deviation)}").to_s
          else
            warning("▼ #{Format.points(deviation)}").to_s
          end
        elsif position.buy?
          muted("+#{position.shares} #{position.shares == 1 ? "share" : "shares"}").to_s
        else
          ""
        end
      end

      private def fallbacks_used : Nil
        failed = @prices.failed
        return if failed.empty?

        @io.puts
        names = failed.map(&.first).join(", ")
        paragraph("#{names} didn't come from the internet on this run " \
                  "(see QUOTES above). Check the price before placing the order.")
      end
    end
  end
end
