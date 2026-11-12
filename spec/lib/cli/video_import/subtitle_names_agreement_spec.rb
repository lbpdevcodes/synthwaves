require "rails_helper"
require_relative "../../../../lib/cli/video_import"

# bin/import_videos names the text tracks it pulls out of a video file. This
# files them through the server's real SubtitleImport, so the labels a viewer
# sees match what the tracks say.
RSpec.describe "Subtitle tracks pulled out by bin/import_videos, on the server" do
  before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

  it "labels each track by its language, marks captions, and numbers a repeat" do
    video = create(:video)

    Dir.mktmpdir do |dir|
      movie = VideoClips.with_subtitles(File.join(dir, "Half.Baked.1998.1080p.mkv"), [
        {language: "eng", title: "English", text: "Hello"},
        {language: "eng", title: "SDH", text: "[door creaks] Hello"},
        {language: "eng", title: "English", text: "Hi"},
        {language: "und", title: "", text: "Hey"}
      ])
      VideoImport::EmbeddedSubtitles.new.extract(movie, dir).each do |srt|
        expect(SubtitleImport.new(video: video, filename: File.basename(srt), data: File.read(srt)).save).to be(true)
      end
    end

    expect(video.subtitles.reorder(:id).pluck(:label, :language, :kind)).to eq([
      ["English", "en", "subtitles"],
      ["English (SDH)", "en", "captions"],
      ["English 2", "en", "subtitles"],
      ["Subtitles", nil, "subtitles"]
    ])
  end
end
