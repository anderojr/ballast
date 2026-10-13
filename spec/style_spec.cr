require "./spec_helper"

private def bar(fraction : Float64, mark : Float64) : String
  io = IO::Memory.new
  Ballast::TUI::Style.bar(io, fraction, 22, :cyan, mark: mark)
  io.to_s
end

describe Ballast::TUI::Style do
  it "puts the target mark in the cell that contains the target" do
    bar(0.10, mark: 0.16).index('┊').should eq 3
  end

  it "hides the mark once the bar reaches the target's cell" do
    bar(0.161, mark: 0.16).should_not contain '┊'
  end
end
