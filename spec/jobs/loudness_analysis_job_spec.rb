require "rails_helper"

RSpec.describe LoudnessAnalysisJob, type: :job do
  let(:track) { create(:track) }

  describe "#perform" do
    it "does nothing when the track is gone" do
      expect { described_class.perform_now(-1) }.not_to raise_error
    end

    it "does nothing when no audio file is attached" do
      youtube_track = create(:track, :youtube)
      expect { described_class.perform_now(youtube_track.id) }.not_to raise_error
      expect(youtube_track.reload.loudness_lufs).to be_nil
    end

    context "with an attached audio file" do
      before do
        track.audio_file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )
      end

      it "stores the measured loudness and playback gain on the track" do
        described_class.perform_now(track.id)
        track.reload

        expect(track.loudness_lufs).to be_a(Float)
        expect(track.loudness_gain_db).to be_a(Float)
        expect(track.loudness_gain_db).to be <= [-14.0 - track.loudness_lufs, -1.0].max + 0.01
      end

      it "logs and moves on when analysis fails" do
        allow(LoudnessAnalyzer).to receive(:call).and_raise(LoudnessAnalyzer::Error, "corrupt file")

        expect(Rails.logger).to receive(:warn).with(/corrupt file/)
        expect { described_class.perform_now(track.id) }.not_to raise_error
        expect(track.reload.loudness_lufs).to be_nil
      end
    end
  end
end
