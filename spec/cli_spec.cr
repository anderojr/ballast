require "./spec_helper"
require "file_utils"

# Runs the whole CLI with in-memory IOs and fake sources
private def run_cli(argv : Array(String), input = "", usd_rate = "5.20",
                    foreign = {"IVV" => dec("776.60"), "VT" => dec("161.54")} of String => BigDecimal | String)
  output = IO::Memory.new
  errors = IO::Memory.new
  cli = Ballast::CLI.new(
    input: IO::Memory.new(input),
    output: output,
    errors: errors,
    fx_source: Ballast::FakeSource.new({"USD" => dec(usd_rate)} of String => BigDecimal | String, name: "AwesomeAPI"),
    foreign_source: Ballast::FakeSource.new(foreign, name: "Finnhub"),
  )
  code = cli.run(argv)
  {code, output.to_s, errors.to_s}
end

private def with_portfolio(yaml = PORTFOLIO_YML, &)
  dir = File.tempname("ballast")
  Dir.mkdir(dir)
  path = File.join(dir, "portfolio.yml")
  File.write(path, yaml)
  yield path
ensure
  FileUtils.rm_rf(dir) if dir
end

describe Ballast::CLI do
  it "runs the whole flow without questions" do
    with_portfolio do |cfg|
      code, output, _ = run_cli(["-c", cfg, "-a", "1500", "-y"])
      code.should eq 0
      output.should match /buy    3 × B5P211.+\n.+buy   10 × VWRA11/ # target before residual
      output.should match /left in cash\s+R\$\s+3,54/
      output.should contain "✔ on target"
      output.should_not contain "Check the price"
    end
  end

  it "asks for the contribution and B3 prices; Enter keeps the file's" do
    with_portfolio do |cfg|
      code, output, _ = run_cli(["-c", cfg], input: "1.500,00\n\n110,12\n")
      code.should eq 0
      output.should contain "VWRA11  R$ [116,61] ›"
      output.should contain "buy    3 × B5P211"
    end
  end

  it "keeps asking until it gets a valid amount" do
    with_portfolio do |cfg|
      _, output, _ = run_cli(["-c", cfg, "-y"], input: "a lot\n1500\n")
      output.should contain %(couldn't read "a lot")
      output.should contain "contribution R$ 1.500,00"
    end
  end

  it "warns when Finnhub fails and uses the file's price with -y" do
    with_portfolio do |cfg|
      foreign = {"IVV" => "hit the 60 req/min limit", "VT" => dec("161.54")} of String => BigDecimal | String
      code, output, _ = run_cli(["-c", cfg, "-a", "1500", "-y"], foreign: foreign)
      code.should eq 0
      output.should contain "✖ IVV      Finnhub unavailable: hit the 60 req/min limit"
      output.should contain "↳ using US$ 776,60 from portfolio.yml"
      output.should contain "IVV didn't come from the internet"
    end
  end

  it "asks for the price when the source fails in interactive mode" do
    with_portfolio do |cfg|
      foreign = {"IVV" => "timed out", "VT" => dec("161.54")} of String => BigDecimal | String
      _, output, _ = run_cli(["-c", cfg, "-a", "1500"], input: "\n\n780\n", foreign: foreign)
      output.should contain "IVV      US$ [776,60] ›"
      output.should match /IVV.+US\$\s+780,00/
    end
  end

  it "doesn't call the APIs in offline mode" do
    with_portfolio do |cfg|
      code, output, _ = run_cli(["-c", cfg, "-a", "1500", "-y", "--offline"])
      code.should eq 0
      output.should contain "portfolio.yml (offline)"
    end
  end

  it "exits with 2 and explains the invalid config" do
    with_portfolio("assets:\n  A: {quantity: 1, currency: BRL}\n") do |cfg|
      code, _, errors = run_cli(["-c", cfg, "-a", "100"])
      code.should eq 2
      errors.should contain "invalid portfolio"
      errors.should contain "residual: true"
    end
  end

  it "exits with 2 on an invalid option" do
    code, _, errors = run_cli(["--does-not-exist"])
    code.should eq 2
    errors.should contain "unknown option: --does-not-exist"

    code, _, errors = run_cli(["-a", "ten"])
    code.should eq 2
    errors.should contain %(invalid amount: "ten")
  end

  it "exits with 130 when the input ends" do
    with_portfolio do |cfg|
      code, output, _ = run_cli(["-c", cfg], input: "")
      code.should eq 130
      output.should contain "cancelled"
    end
  end

  it "shows help and version" do
    run_cli(["--help"])[1].should contain "FINNHUB_API_KEY"
    run_cli(["--version"])[1].should eq "ballast #{Ballast::VERSION}\n"
  end
end
