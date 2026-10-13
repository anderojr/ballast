module Ballast
  # The role of each asset in the month's contribution
  #
  # This is a union of types, not an enum: Target carries the target fraction
  # while the others carry no data. With case ... in, the compiler enforces
  # handling all three cases, ensuring a new role doesn't go unnoticed
  module Allocation
    # Receives no contribution, only counts towards the total portfolio value
    record Hold

    # Receives a contribution until it reaches fraction of the total
    # portfolio value post-contribution
    record Target, fraction : BigDecimal

    # Receives whatever remains after targets have been met
    record Residual

    alias Kind = Hold | Target | Residual
  end
end
