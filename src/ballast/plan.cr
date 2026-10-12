module Ballast
  ZERO = BigDecimal.new(0)

  # One line of the plan: the asset, where it stood and how much to buy
  record Position,
    asset : Asset,
    # Price of one share in BRL
    price : BigDecimal,
    # Value of the position before buying, in BRL
    before : BigDecimal,
    shares : Int32 = 0,
    # For targets: how much was missing to reach it, contribution included
    gap : BigDecimal = ZERO do
    def cost : BigDecimal
      price * shares
    end

    def after : BigDecimal
      before + cost
    end

    def buy? : Bool
      shares > 0
    end
  end

  # Result of the rebalancing. Only data and derived math: the Rebalancer
  # picks the shares and the Report draws them
  record Plan, contribution : BigDecimal, positions : Array(Position) do
    def total_before : BigDecimal
      positions.sum(ZERO, &.before)
    end

    def invested : BigDecimal
      positions.sum(ZERO, &.cost)
    end

    def leftover : BigDecimal
      contribution - invested
    end

    def total_after : BigDecimal
      total_before + invested
    end

    def purchases : Array(Position)
      positions.select(&.buy?)
    end

    def weight_before(position : Position) : BigDecimal
      fraction(position.before, total_before)
    end

    def weight_after(position : Position) : BigDecimal
      fraction(position.after, total_after)
    end

    # For targets: how much is still missing after buying (negative = overshot)
    def missing_to_target(position : Position) : BigDecimal?
      position.asset.target_fraction.try { |target| target * total_after - position.after }
    end

    private def fraction(part : BigDecimal, whole : BigDecimal) : BigDecimal
      whole.zero? ? ZERO : part / whole
    end
  end
end
