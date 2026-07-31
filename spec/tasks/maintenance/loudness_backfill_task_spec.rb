require "rails_helper"

RSpec.describe Maintenance::LoudnessBackfillTask do
  let(:task) { described_class.new }

  def create_streamable_track(loudness_lufs: nil)
    track = create(:track, loudness_lufs: loudness_lufs)
    track.audio_file.attach(
      io: StringIO.new("fake audio"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )
    track
  end

  describe "#collection" do
    it "includes streamable tracks that have not been analyzed" do
      track = create_streamable_track
      expect(task.collection).to include(track)
    end

    it "excludes tracks that already have loudness measurements" do
      track = create_streamable_track(loudness_lufs: -20.5)
      expect(task.collection).not_to include(track)
    end

    it "excludes tracks with no audio file" do
      track = create(:track, :youtube)
      expect(task.collection).not_to include(track)
    end
  end

  describe "#process" do
    it "enqueues LoudnessAnalysisJob for the track" do
      track = create_streamable_track

      expect { task.process(track) }
        .to have_enqueued_job(LoudnessAnalysisJob).with(track.id)
    end
  end
end
