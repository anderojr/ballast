require "colorize"

module Ballast
  module TUI
    WIDTH = 72

    # Palette and drawing pieces. Everything goes through `Colorize`, which
    # turns itself off when the output isn't a terminal or `NO_COLOR` is set.
    #
    # Alignment rule: pad the plain text first, color it afterwards.
    # ANSI codes take no column on screen, but they count in `String#size`
    module Style
      extend self

      BLOCKS = {"", "▏", "▎", "▍", "▌", "▋", "▊", "▉"}

      def title(s : String) : Colorize::Object(String)
        s.colorize(:cyan).bold
      end

      def muted(s : String) : Colorize::Object(String)
        s.colorize(:dark_gray)
      end

      def strong(s : String) : Colorize::Object(String)
        s.colorize.bold
      end

      def ok(s : String) : Colorize::Object(String)
        s.colorize(:green)
      end

      def warning(s : String) : Colorize::Object(String)
        s.colorize(:yellow)
      end

      def error(s : String) : Colorize::Object(String)
        s.colorize(:red)
      end

      def left(s : String, width : Int32) : String
        s.ljust(width)
      end

      def right(s : String, width : Int32) : String
        s.rjust(width)
      end

      # HEADING ─────────────────────────────── text on the right
      def section(io : IO, heading : String, aside : String? = nil) : Nil
        used = 1 + heading.size + 1 + (aside ? aside.size + 1 : 0)
        io.puts
        io << " " << title(heading) << " " << muted("─" * Math.max(3, WIDTH - used))
        io << " " << strong(aside) if aside
        io.puts
      end

      def box(io : IO, heading : String, aside : String) : Nil
        inner = WIDTH - 4
        gap = Math.max(1, inner - heading.size - aside.size)
        io.puts muted("╭#{"─" * (WIDTH - 2)}╮")
        io << muted("│ ") << title(heading) << " " * gap << muted(aside) << muted(" │") << '\n'
        io.puts muted("╰#{"─" * (WIDTH - 2)}╯")
      end

      # Horizontal bar with 1/8-character resolution. *mark* draws a `┊`
      # where the target sits, if it falls in the empty part.
      def bar(io : IO, fraction : Number, width : Int32, color : Colorize::ColorANSI, mark : Number? = nil) : Nil
        eights = (fraction.to_f * width * 8).round.to_i.clamp(0, width * 8)
        full, rest = eights.divmod(8)
        filled = "█" * full + BLOCKS[rest]

        empty = Array.new(width - filled.size, ' ')
        if mark
          i = (mark.to_f * width).round.to_i - filled.size
          empty[i] = '┊' if 0 <= i < empty.size
        end

        io << filled.colorize(color) << muted(empty.join)
      end
    end
  end
end
