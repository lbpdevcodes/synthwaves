require "rails_helper"
require_relative "../../../../lib/cli/video_import"

# For a file VideoConversionJob would keep as it is, bin/import_video sends
# the details and thumbnail the job would make, and the job does not run.
# This makes both from the same file, on each side, and expects them equal.
RSpec.describe "Details and thumbnail bin/import_video sends, against the server's own" do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

  let(:clip) { VideoClips.h264_one_keyframe(@dir) }

  def sent_by_script
    jpeg = nil
    sent = VideoImport::Encoder.new(out: StringIO.new).ready_details(VideoImport::SourceFile.at(clip)) do |thumbnail|
      jpeg = File.binread(thumbnail.path)
      "thumbnail-signed-id"
    end
    [sent, jpeg]
  end

  it "sends the details the job would store" do
    sent, = sent_by_script

    expect(sent[:details]).to eq(VideoMetadataExtractor.call(clip).except(:audio_channel_layout))
  end

  it "sends the thumbnail the job would make, byte for byte" do
    _sent, jpeg = sent_by_script
    video = create(:video, :processing)
    video.file.attach(io: File.open(clip), filename: "long.mp4")

    VideoConversionJob.perform_now(video.id)

    expect(Digest::MD5.base64digest(jpeg)).to eq(video.reload.thumbnail.blob.checksum)
  end
end
