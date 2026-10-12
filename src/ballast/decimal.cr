module Ballast
  # YAML converters for BigDecimal, which lacks native support for
  # YAML::Serializable. Reads the scalar text directly, without passing
  # through Float64, so 0.50127394 is preserved exactly
  module Decimal
    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : BigDecimal
      unless node.is_a?(YAML::Nodes::Scalar) && node.value.matches?(/\A-?\d+(\.\d+)?\z/)
        node.raise "expected a number (e.g., 116.61)"
      end
      BigDecimal.new(node.value)
    end

    # Accepts 16% or 0.16, both become 0.16
    module Percent
      def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : BigDecimal
        unless node.is_a?(YAML::Nodes::Scalar) && (m = node.value.match(/\A(\d+(?:\.\d+)?)\s*(%?)\z/))
          node.raise "expected a percentage (e.g., 16% or 0.16)"
        end
        value = BigDecimal.new(m[1])
        m[2].empty? ? value : value / 100
      end
    end
  end
end
