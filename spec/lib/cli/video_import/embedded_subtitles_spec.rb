require "tmpdir"
require "json"
require_relative "../../../../lib/cli/video_import"
require_relative "../../../support/video_clips"

RSpec.describe VideoImport::EmbeddedSubtitles do
  let(:subtitles) { described_class.new }
  let(:english) { {language: "eng", title: "English", text: "Hello"} }
  let(:sdh) { {language: "eng", title: "SDH", text: "[door creaks] Hello"} }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @out = File.join(dir, "out").tap { |path| Dir.mkdir(path) }
      example.run
    end
  end

  before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

  def clip(*tracks) = VideoClips.with_subtitles(File.join(@dir, "movie.mkv"), tracks)

  def tool(name, script) = File.join(@dir, name).tap { |path| File.write(path, "#!/bin/sh\n#{script}\n") && File.chmod(0o755, path) }

  it "writes each text track inside a video to an .srt file named for its language" do
    srt = subtitles.extract(clip(english), @out)

    expect(srt.map { |path| File.basename(path) }).to eq(["eng.srt"])
    expect(File.read(srt.first)).to include("Hello")
  end

  it "marks a track for deaf viewers as SDH, the way the server reads it" do
    srt = subtitles.extract(clip(english, sdh), @out)

    expect(srt.map { |path| [File.basename(path), File.read(path)[/\[door creaks\]/]] }).to eq([["eng.srt", nil], ["SDH.eng.srt", "[door creaks]"]])
  end

  it "numbers tracks that would share a name" do
    srt = subtitles.extract(clip(english, english.merge(text: "Hi")), @out)

    expect(srt.map { |path| File.basename(path) }).to eq(["eng.srt", "eng.2.srt"])
  end

  it "counts the text tracks without writing anything" do
    expect(subtitles.names(clip(english, sdh))).to eq(["eng", "SDH.eng"])
    expect(Dir.children(@out)).to be_empty
  end

  it "leaves out image subtitles, which cannot become text" do
    streams = [{index: 0, codec_type: "video", codec_name: "h264"}, {index: 2, codec_type: "subtitle", codec_name: "hdmv_pgs_subtitle", tags: {language: "eng"}}]
    ffprobe = tool("ffprobe", "echo '#{JSON.generate(streams: streams, format: {})}'")

    expect(described_class.new(ffprobe: ffprobe).names(clip(english))).to eq([])
  end

  it "names ffmpeg's reason when it cannot write the subtitles out" do
    ffmpeg = tool("ffmpeg", "echo 'Error opening output eng.srt: Permission denied' >&2; exit 1")

    expect { described_class.new(ffmpeg: ffmpeg).extract(clip(english), @out) }
      .to raise_error(VideoImport::Error, "could not read the subtitles inside movie.mkv: Error opening output eng.srt: Permission denied")
  end
end
