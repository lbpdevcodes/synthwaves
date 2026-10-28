require "rails_helper"

RSpec.describe CancellableCommand do
  let(:never) { -> { false } }

  describe ".run" do
    it "reports success for a command that exits zero" do
      expect(described_class.run("true", cancelled: never)).to eq(:succeeded)
    end

    it "reports failure for a command that exits non-zero" do
      expect(described_class.run("false", cancelled: never)).to eq(:failed)
    end

    it "stops a running command once it is cancelled" do
      checks = 0
      cancelled_on_second_check = -> { (checks += 1) > 1 }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      outcome = described_class.run("sleep", "30", cancelled: cancelled_on_second_check, poll_interval: 0.01)

      expect(outcome).to eq(:cancelled)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
    end
  end
end
