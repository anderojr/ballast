require "spec"
require "../src/rebalancing"

def dec(value : String | Int32) : BigDecimal
  BigDecimal.new(value)
end
