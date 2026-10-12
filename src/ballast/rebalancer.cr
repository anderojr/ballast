module Ballast
  # Decides how many shares of each asset to buy. No I/O: takes the
  # portfolio and the prices and returns a `Plan`.
  #
  # The rule:
  #
  # 1. Each asset with a target has a gap: how much it's missing to be worth
  #    `target × (current total + contribution)`. Never negative, since
  #    nothing is sold.
  # 2. If the gaps fit in the contribution, each target gets its own.
  #    If they don't, the contribution is split in proportion to the gaps.
  # 3. Each target's budget becomes shares with regular rounding (it may
  #    overshoot the target a little, which is fine), but never above the
  #    money still left.
  # 4. Whatever is left goes to the residual asset, rounded down.
  #    The final change stays in cash.
  class Rebalancer
    def initialize(@portfolio : Portfolio, @prices : Prices)
    end

    def plan(contribution : BigDecimal) : Plan
      raise ArgumentError.new("the contribution must be greater than zero") unless contribution > 0

      positions = @portfolio.assets.map do |asset|
        price = @prices.in_brl(asset)
        Position.new(asset, price, before: price * asset.quantity)
      end

      total_with_contribution = positions.sum(ZERO, &.before) + contribution
      positions = positions.map { |position| position.copy_with(gap: gap(position, total_with_contribution)) }

      gap_sum = positions.sum(ZERO, &.gap)
      scale = gap_sum > contribution ? contribution / gap_sum : BigDecimal.new(1)
      cash = contribution

      positions = positions.map do |position|
        case position.asset.allocation
        in Allocation::Target
          shares = Math.min((position.gap * scale / position.price).round(:ties_even).to_i, affordable(cash, position.price))
          cash -= position.price * shares
          position.copy_with(shares: shares)
        in Allocation::Hold, Allocation::Residual
          position
        end
      end

      # The residual comes after every target, wherever it sits in the file
      positions = positions.map do |position|
        position.asset.residual? ? position.copy_with(shares: affordable(cash, position.price)) : position
      end

      Plan.new(contribution, positions)
    end

    private def gap(position : Position, total : BigDecimal) : BigDecimal
      target = position.asset.target_fraction || return ZERO
      Math.max(ZERO, target * total - position.before)
    end

    private def affordable(money : BigDecimal, price : BigDecimal) : Int32
      (money / price).floor.to_i
    end
  end
end
