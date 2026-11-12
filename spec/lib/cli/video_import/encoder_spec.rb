require "tmpdir"
require "stringio"
require_relative "../../../../lib/cli/video_import"
require_relative "../../../support/video_clips"

RSpec.describe VideoImport::Encoder do
  let(:out) { StringIO.new }
  let(:encoder) { described_class.new(out: out) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

  def handed_over(clip)
    encoder.prepare(VideoImport::SourceFile.at(clip)) { |source| return source }
  end

  it "hands over an H.264, stereo AAC MP4 as it is" do
    clip = VideoClips.h264(@dir)

    expect(handed_over(clip).path).to eq(clip)
  end

  it "converts only the sound of an H.264 file with surround sound, to stereo AAC in an MP4" do
    clip = VideoClips.h264_surround(@dir)
    copy = encoder.prepare(VideoImport::SourceFile.at(clip)) { |source| [VideoClips.streams(source.path), VideoClips.stream_hash(source.path, :video)] }

    expect(copy.first).to include(audio: "aac", channels: 2, container: a_string_including("mp4"))
    expect(copy.last).to eq(VideoClips.stream_hash(clip, :video))
  end

  it "repackages an H.264, stereo AAC Matroska file as an MP4 without converting either stream" do
    clip = VideoClips.h264_matroska(@dir)
    copy = encoder.prepare(VideoImport::SourceFile.at(clip)) do |source|
      [VideoClips.streams(source.path)[:container], %i[video audio].map { |type| VideoClips.stream_hash(source.path, type) }]
    end

    expect(copy.first).to include("mp4")
    expect(copy.last).to eq(%i[video audio].map { |type| VideoClips.stream_hash(clip, type) })
  end

  it "hands over an H.264, stereo AAC MP4 copy of anything else, named after the source" do
    clip = VideoClips.mpeg4_surround(@dir)
    copy = encoder.prepare(VideoImport::SourceFile.at(clip)) { |source| [source.filename, VideoClips.streams(source.path)] }

    expect(copy.first).to eq("clip.mp4")
    expect(copy.last).to include(video: "h264", audio: "aac", channels: 2, container: a_string_including("mp4"))
  end

  it "reports how far the encoding has got" do
    encoder.prepare(VideoImport::SourceFile.at(VideoClips.mpeg4_surround(@dir))) { |_source| }

    expect(out.string).to start_with("\rEncoding clip.mkv:").and end_with("100%\n")
  end

  it "deletes the encoded copy once the upload is over, even when the upload fails" do
    clip = VideoClips.mpeg4_surround(@dir)
    copy = nil

    expect {
      encoder.prepare(VideoImport::SourceFile.at(clip)) do |source|
        copy = source.path
        raise VideoImport::Error, "storage rejected the upload (403): AccessDenied"
      end
    }.to raise_error(VideoImport::Error, /AccessDenied/)
    expect(File.exist?(copy)).to be(false)
  end

  it "leaves the source file as it was" do
    clip = VideoClips.mpeg4_surround(@dir)
    before = [File.size(clip), File.mtime(clip), Digest::MD5.file(clip).hexdigest]

    encoder.prepare(VideoImport::SourceFile.at(clip)) { |_source| }

    expect([File.size(clip), File.mtime(clip), Digest::MD5.file(clip).hexdigest]).to eq(before)
  end

  describe "when it cannot encode" do
    it "names a file ffprobe cannot read as a video" do
      notes = File.join(@dir, "notes.mkv")
      File.write(notes, "not a video")

      expect { encoder.prepare(VideoImport::SourceFile.at(notes)) { |_source| } }
        .to raise_error(VideoImport::Error, "could not read #{notes} as a video: Invalid data found when processing input")
    end

    it "names ffmpeg's own reason when the encoding fails" do
      failing = File.join(@dir, "failing-ffmpeg")
      File.write(failing, "#!/bin/sh\necho \"[aac @ 0x1] Unsupported channel layout\" >&2\necho \"Conversion failed!\" >&2\nexit 1\n")
      File.chmod(0o755, failing)
      encoder = described_class.new(out: out, ffmpeg: failing)

      expect { encoder.prepare(VideoImport::SourceFile.at(VideoClips.mpeg4_surround(@dir))) { |_source| } }
        .to raise_error(VideoImport::Error, "encoding clip.mkv failed (exit 1): [aac @ 0x1] Unsupported channel layout")
    end

    it "says how to get ffprobe when it is not installed" do
      encoder = described_class.new(out: out, ffprobe: "no-such-ffprobe")

      expect { encoder.prepare(VideoImport::SourceFile.at(VideoClips.h264(@dir))) { |_source| } }
        .to raise_error(VideoImport::Error, "no-such-ffprobe is not installed: install ffmpeg (brew install ffmpeg), or pass --no-encode to let the server convert the video")
    end

    it "says how to get ffmpeg when it is not installed" do
      encoder = described_class.new(out: out, ffmpeg: "no-such-ffmpeg")

      expect { encoder.prepare(VideoImport::SourceFile.at(VideoClips.mpeg4_surround(@dir))) { |_source| } }
        .to raise_error(VideoImport::Error, "no-such-ffmpeg is not installed: install ffmpeg (brew install ffmpeg), or pass --no-encode to let the server convert the video")
    end
  end
end
