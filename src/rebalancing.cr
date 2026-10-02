require "big"

# Calculate how to split monthly deposit among the portfolio's assets
#
# This file is just the library, the executable is located at src/cli.cr
# This allows the specs to require it without triggering the program
module Rebalancing
  VERSION = "0.1.0"
end
