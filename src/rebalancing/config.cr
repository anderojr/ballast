module Rebalancing
  # Shape of portfolio.yml. It only deserializes and validates,
  # the result is a Portfolio
  #
  # "Strict" turns unknown keys into errors, so "targets: 16%" (with an "s")
  # gets reported instead of silently ignored
  class Config
    include YAML::Serializable
    include YAML::Serializable::Strict

    DEFAULT_PATHS = [
      Path["portfolio.yml"],
      Path.home / ".config" / "rebalancing" / "portfolio.yml",
    ]

    struct AssetConfig
      include YAML::Serializable
      include YAML::Serializable::Strict

      @[YAML::Field(converter: Rebalancing::Decimal)]
      getter quantity : BigDecimal

      getter currency : Currency

      @[YAML::Field(converter: Rebalancing::Decimal)]
      getter price : BigDecimal? = nil

      @[YAML::Field(converter: Rebalancing::Decimal::Percent)]
      getter target : BigDecimal? = nil

      getter? residual : Bool = false

      # Optional. Default : USD -> finnhub, BRL -> manual
      getter price_source : PriceSource? = nil

      def problems : Array(String)
        list = [] of String
        list << "quantity can't be negative" if quantity < 0
        list << "price must be greater than zero" if price.try(&.<= 0)
        list << "target must be between 0% and 100%" if target.try { |fraction| !(0 < fraction < 1) }
        list << "pick `target` or `residual`, not both" if target && residual?
        list << "Finnhub (free plan) only quotes USD assets" if price_source.try(&.finnhub?) && !currency.usd?
        list
      end
    end

    # Fallback USD/BRL rate, if AwesomeAPI doesn't answer
    @[YAML::Field(converter: Rebalancing::Decimal)]
    getter usd_rate : BigDecimal? = nil

    getter assets : Hash(String, AssetConfig)

    # First file that exists among DEFAULT_PATHS
    def self.locate : Path?
      DEFAULT_PATHS.find { |path| File.exists?(path) }
    end

    def self.load(path : Path) : Portfolio
      unless File.exists?(path)
        raise ConfigError.new("file #{path} not found")
      end
      from_yaml(File.read(path)).to_portfolio
    rescue ex : YAML::ParseException
      raise ConfigError.new("#{path}: #{ex.message}")
    end

    def to_portfolio : Portfolio
      problems = validate
      raise ConfigError.new(problems) unless problems.empty?

      list = assets.map do |ticker, entry|
        Asset.new(
          ticker: ticker,
          quantity: entry.quantity,
          currency: entry.currency,
          allocation: allocation_for(entry),
          price_source: entry.price_source || (entry.currency.usd? ? PriceSource::Finnhub : PriceSource::Manual),
          last_known_price: entry.price,
        )
      end
      Portfolio.new(list, usd_rate)
    end

    private def allocation_for(entry : AssetConfig) : Allocation::Kind
      if target = entry.target
        Allocation::Target.new(target)
      elsif entry.residual?
        Allocation::Residual.new
      else
        Allocation::Hold.new
      end
    end

    private def validate : Array(String)
      problems = assets.flat_map { |ticker, entry| entry.problems.map { |msg| "#{ticker}: #{msg}" } }
      problems.unshift("no assets under `assets`") if assets.empty?

      residuals = assets.select { |_, entry| entry.residual? }.keys
      case residuals.size
      when 0 then problems << "mark one asset with `residual: true` (it receives what's left of the contribution)"
      when 1 # ok
      else problems << "there can be only one residual asset (found #{residuals.join(", ")})"
      end

      target_sum = assets.each_value.compact_map(&.target).sum(BigDecimal.new(0))
      if target_sum > 1
        problems << "targets add up to more than 100% (#{Format.percent(target_sum)})"
      end

      if (rate = usd_rate) && rate <= 0
        problems << "usd_rate must be greater than zero"
      end

      problems
    end
  end
end
