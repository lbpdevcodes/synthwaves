require "tmpdir"
require "stringio"
require_relative "../../../../lib/cli/video_import"
require_relative "../../../support/video_clips"

RSpec.describe VideoImport::ReadyDetails do
  let(:out) { StringIO.new }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

  def source(clip) = VideoImport::SourceFile.at(clip)

  it "describes a file the server keeps as it is, and hands its JPEG thumbnail over to be stored" do
    stored = []
    sent = described_class.new(out: out).for(source(VideoClips.h264(@dir))) do |thumbnail|
      stored << [thumbnail.filename, thumbnail.content_type, File.binread(thumbnail.path, 2).bytes]
      "thumbnail-signed-id"
    end

    expect(stored).to eq([["thumbnail.jpg", "image/jpeg", [0xFF, 0xD8]]])
    expect(sent).to include(thumbnail_signed_blob_id: "thumbnail-signed-id")
    expect(sent[:details]).to include(video_codec: "h264", audio_codec: "aac", audio_channels: 2, width: 320, height: 240)
  end

  it "sends nothing for a file the server would still convert, and makes no thumbnail" do
    stored = []

    sent = described_class.new(out: out).for(source(VideoClips.h264_surround(@dir))) { |thumbnail| stored << thumbnail }

    expect([sent, stored]).to eq([{}, []])
  end

  it "leaves both to the server when it cannot make the thumbnail, and says why" do
    ffmpeg = File.join(@dir, "failing-ffmpeg")
    File.write(ffmpeg, "#!/bin/sh\necho 'thumbnail.jpg: No space left on device' >&2\nexit 1\n")
    File.chmod(0o755, ffmpeg)

    sent = described_class.new(out: out, ffmpeg: ffmpeg).for(source(VideoClips.h264(@dir))) { "never" }

    expect(sent).to eq({})
    expect(out.string).to include("The server will make the thumbnail: thumbnail.jpg: No space left on device")
  end

  it "deletes the thumbnail once it has been stored" do
    path = nil

    described_class.new(out: out).for(source(VideoClips.h264(@dir))) { |thumbnail| path = thumbnail.path }

    expect(File.exist?(path)).to be(false)
  end

  it "is what --no-encode skips: the server makes the details and thumbnail itself" do
    expect(VideoImport::PassThrough.new.ready_details(source(VideoClips.h264(@dir))) { "never" }).to eq({})
  end
end
