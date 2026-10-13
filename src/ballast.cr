require "big"
require "big/json"
require "json"
require "yaml"

require "./ballast/errors"
require "./ballast/currency"
require "./ballast/format"
require "./ballast/decimal"
require "./ballast/allocation"
require "./ballast/asset"
require "./ballast/portfolio"
require "./ballast/config"
require "./ballast/quote"
require "./ballast/plan"
require "./ballast/rebalancer"
require "./ballast/sources/source"
require "./ballast/sources/awesome_api"
require "./ballast/sources/finnhub"
require "./ballast/quoter"
require "./ballast/tui/style"
require "./ballast/tui/spinner"
require "./ballast/tui/prompt"
require "./ballast/tui/report"
require "./ballast/cli"

# Calculate how to split monthly deposit among the portfolio's assets
#
# This file is just the library, the executable is located at src/cli.cr
# This allows the specs to require it without triggering the program
module Ballast
  VERSION = "0.1.2"
end
