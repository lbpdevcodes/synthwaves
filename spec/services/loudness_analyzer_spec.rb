require "rails_helper"

RSpec.describe LoudnessAnalyzer, type: :service do
  let(:file_path) { Rails.root.join("spec/fixtures/files/test.mp3").to_s }

  describe ".call" do
    it "measures integrated loudness and true peak with ffmpeg" do
      result = described_class.call(file_path)

      expect(result[:integrated_lufs]).to be_a(Float)
      expect(result[:integrated_lufs]).to be_between(-70, 0)
      expect(result[:true_peak_db]).to be_a(Float)
    end

    it "computes gain toward the -14 LUFS target" do
      result = described_class.call(file_path)

      expected = [-14.0 - result[:integrated_lufs], -1.0 - result[:true_peak_db]].min
      expect(result[:gain_db]).to be_within(0.001).of(expected)
    end

    context "when boosting to target would exceed the true-peak ceiling" do
      let(:loudnorm_json) do
        <<~OUTPUT
          [Parsed_loudnorm_0 @ 0x7f8]  some log line
          {
          	"input_i" : "-30.00",
          	"input_tp" : "-0.20",
          	"input_lra" : "5.0",
          	"input_thresh" : "-40.00",
          	"output_i" : "-14.00",
          	"output_tp" : "-1.00",
          	"normalization_type" : "dynamic"
          }
        OUTPUT
      end

      it "clamps gain so the true peak stays at or below -1 dBTP" do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return(["", loudnorm_json, status])

        result = described_class.call(file_path)

        # Raw gain would be +16 dB; ceiling is -1.0 - (-0.2) = -0.8 dB
        expect(result[:gain_db]).to eq(-0.8)
      end
    end

    context "when ffmpeg fails" do
      it "raises LoudnessAnalyzer::Error" do
        status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(["", "boom", status])

        expect { described_class.call(file_path) }.to raise_error(LoudnessAnalyzer::Error, /boom/)
      end
    end
  end
end
