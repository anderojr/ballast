module Ballast
  module TUI
    # Spins a spinner in its own fiber while the block runs.
    #
    # Control is channels only: `stop` tells the fiber to quit and `stopped`
    # guarantees it erased the line before anything else gets written, so
    # the spinner never gets mixed up with the output that follows.
    module Spinner
      FRAMES   = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏]
      INTERVAL = 80.milliseconds

      def self.spin(io : IO, text : String, & : -> T) : T forall T
        return yield unless io.tty? && Colorize.enabled?

        stop = Channel(Nil).new
        stopped = Channel(Nil).new

        spawn(name: "spinner") do
          frame = 0
          loop do
            io << "\r   " << FRAMES[frame % FRAMES.size].colorize(:cyan) << " " << Style.muted(text)
            io.flush
            frame += 1
            select
            when stop.receive then break
            when timeout(INTERVAL)
            end
          end

          begin
            yield
          ensure
            stop.send(nil)
            stopped.receive
          end
        end
      end
    end
  end
end
