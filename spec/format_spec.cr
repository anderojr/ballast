require "./spec_helper"

describe Ballast::Format do
  describe ".parse_amount?" do
    {
      "1500"        => "1500",
      "1500.50"     => "1500.5",
      "1.500"       => "1500",
      "1.500,50"    => "1500.5",
      "1500,5"      => "1500.5",
      "R$ 1.234,56" => "1234.56",
      "  116,61"    => "116.61",
      "US$ 776.60"  => "776.6",
      "1.234.567"   => "1234567",
    }.each do |input, expected|
      it "read #{input.inspect}" do
        Ballast::Format.parse_amount?(input).should eq dec(expected)
      end
    end
  end

  ["", "abc", "1,2,3", "-10", "1.2.3,4,5", "12a"].each do |input|
    it "reject #{input.inspect}" do
      Ballast::Format.parse_amount?(input).should be_nil
    end
  end

  it "format money on brazilian standard" do
    Ballast::Format.money(dec("1234567.891")).should eq "R$ 1.234.567,89"
    Ballast::Format.money(dec("-3.5")).should eq "-R$ 3,50"
    Ballast::Format.money(dec("776.6"), Ballast::Currency::USD).should eq "US$ 776,60"
  end

  it "align columns by symbol" do
    Ballast::Format.money_column(dec("512.30"), 14).should eq " R$     512,30"
    Ballast::Format.money_column(dec("2048.90"), 14).should eq " R$   2.048,90"
    Ballast::Format.money_column(dec("776.6"), 14, Ballast::Currency::USD).should eq "US$     776,60"
  end

  it "display whole quantities without decimal places and fractional quantities without trailing zeros" do
    Ballast::Format.quantity(dec(80)).should eq "80"
    Ballast::Format.quantity(dec("0.50127394")).should eq "0,50127394"
    Ballast::Format.quantity(dec("1.5")).should eq "1,5"
  end

  it "display the price with the number of decimal places it has, between 2 and 6" do
    Ballast::Format.price(dec("5.3412")).should eq "5,3412"
    Ballast::Format.price(dec("776.6")).should eq "776,60"
  end

  it "formats percentages and percentage points" do
    Ballast::Format.percent(dec("0.1598")).should eq "16,0%"
    Ballast::Format.points(dec("0.004")).should eq "+0,4 p.p."
    Ballast::Format.points(dec("-0.012")).should eq "−1,2 p.p."
  end
end
