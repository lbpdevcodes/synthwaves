require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"
require_relative "../support/video_clips"
require_relative "../support/fake_synthwaves"

RSpec.describe "bin/import_videos" do
  let(:script) { File.expand_path("../../bin/import_videos", __dir__) }
  let(:credentials) { {"SYNTHWAVES_CLIENT_ID" => "bc_id", "SYNTHWAVES_SECRET_KEY" => "secret"} }
  let(:no_credentials) { {"SYNTHWAVES_CLIENT_ID" => nil, "SYNTHWAVES_SECRET_KEY" => nil} }

  around do |example|
    Dir.mktmpdir do |folder|
      @folder = folder
      example.run
    end
  end

  def run_script(*args, env: credentials)
    Open3.capture3(env, RbConfig.ruby, script, *args)
  end

  def place(relative)
    File.join(@folder, relative).tap { |path| FileUtils.mkdir_p(File.dirname(path)) }
  end

  def movie(relative) = VideoClips.make(place(relative), "-c:v", "libx264", "-ac", "2")

  it "prints its usage and fails when no folder is given" do
    _out, err, status = run_script

    expect(err).to include("Usage: bin/import_videos FOLDER")
    expect(status.exitstatus).to eq(1)
  end

  it "names a type it doesn't know and fails" do
    _out, err, status = run_script(@folder, "--type", "cartoon")

    expect(err).to include("import_videos: invalid argument: --type cartoon")
    expect(status.exitstatus).to eq(1)
  end

  it "names a folder that does not exist and fails" do
    missing = File.join(@folder, "no-such-folder")

    _out, err, status = run_script(missing)

    expect(err).to include("import_videos: no such folder: #{missing}")
    expect(status.exitstatus).to eq(1)
  end

  it "names the missing credentials for a real run and fails" do
    _out, err, status = run_script(@folder, env: no_credentials)

    expect(err).to include("import_videos: set SYNTHWAVES_CLIENT_ID and SYNTHWAVES_SECRET_KEY")
    expect(status.exitstatus).to eq(1)
  end

  it "names a line in the titles file it cannot read, and fails" do
    File.write(place("synthwaves-titles.txt"), "Theres Something About Mary There's Something About Mary\n")

    _out, err, status = run_script(@folder, "--dry-run")

    expect(err).to include(%(import_videos: synthwaves-titles.txt line 1 has no "=" between the two titles))
    expect(status.exitstatus).to eq(1)
  end

  context "against a server" do
    let(:server) { FakeSynthwaves.new }
    let(:log) { File.join(@folder, "synthwaves-uploaded.log") }

    before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }
    after { server.stop }

    it "uploads each ready video with its subtitles, logs it, and skips it on the next run" do
      movie("Shrek (2001) [1080p]/Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
      File.write(place("Shrek (2001) [1080p]/Shrek.2001.1080p.BluRay.x264.YIFY.srt"), "1\n00:00:00,000 --> 00:00:00,900\nOgres are like onions\n")

      first, _err, status = run_script(@folder, "--host", server.url)
      again, = run_script(@folder, "--host", server.url)

      calls = server.requests.map { |method, path, _| "#{method} #{path}" }
      expect(calls.count("POST /api/import/videos")).to eq(1)
      expect(calls).to include("PUT /storage", "POST /api/import/videos/7/subtitles")
      expect([first.lines.last.chomp, status.exitstatus]).to eq(["Failed 0", 0])
      expect(first).to include(%(Uploaded 1: "Shrek" (video 7)))
      expect(File.read(log)).to start_with("Shrek\tvideo 7\t")
      expect(again).to include(%(Skipping "Shrek" (Shrek.2001.1080p.BluRay.x264.YIFY.mp4): uploaded already as video 7))
    end

    it "files every video with the type and genres given" do
      movie("Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
      movie("Toy.Story.1995.1080p.BluRay.x265.mp4")

      _out, _err, status = run_script(@folder, "--host", server.url, "--type", "movie", "--genre", "animated", "--genre", "comedy")

      filed = server.requests.select { |_, path, _| path == "/api/import/videos" }.map { |*, body| JSON.parse(body) }
      expect(filed.map { |video| video.slice("title", "video_type", "genres") }).to eq([
        {"title" => "Shrek", "video_type" => "movie", "genres" => %w[animated comedy]},
        {"title" => "Toy Story", "video_type" => "movie", "genres" => %w[animated comedy]}
      ])
      expect(status.exitstatus).to eq(0)
    end

    it "reports a video it could not upload, logs nothing for it, and fails" do
      movie("Shrek.2001.1080p.BluRay.x264.YIFY.mp4")

      out, _err, status = run_script(@folder, "--host", "http://127.0.0.1:9")

      expect(out).to include('Failed 1: "Shrek" (connection to 127.0.0.1 failed')
      expect(status.exitstatus).to eq(1)
      expect(File.exist?(log)).to be(false)
    end
  end

  context "with --dry-run" do
    before { skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools? }

    it "lists what it would upload and what it skips, with the reason, and uploads nothing" do
      VideoClips.with_subtitles(place("Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG[TGx]/Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv"),
        [{language: "eng", title: "English", text: "Hello"}, {language: "eng", title: "SDH", text: "[door creaks] Hello"}])
      movie("Shrek (2001) [1080p]/Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
      File.write(place("Shrek (2001) [1080p]/Shrek.2001.1080p.BluRay.x264.YIFY.srt"), "1\n00:00:00,000 --> 00:00:00,900\nOgres are like onions\n")
      File.write(place("Anchorman.2004.1080p.BrRip.x264.YIFY.mp4.part"), "half a movie")
      movie("Kung Fu Hustle 2004 1080p x264.mkv")
      movie("Theres.Something.About.Mary.EXTENDED.CUT.1998.1080p.BrRip.x264.YIFY.mp4")
      File.write(place("synthwaves-uploaded.log"), "Kung Fu Hustle\tvideo 1319\t2026-11-11 21:40:00\n")
      File.write(place("synthwaves-titles.txt"), "Theres Something About Mary = There's Something About Mary\n")

      out, _err, status = run_script(@folder, "--dry-run", env: no_credentials)

      expect(out.lines.map(&:chomp)).to eq([
        %(Skipping "Anchorman" (Anchorman.2004.1080p.BrRip.x264.YIFY.mp4): still downloading),
        %(Would upload "Dazed and Confused" (Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv) with 2 subtitle tracks from inside the file),
        %(Skipping "Kung Fu Hustle" (Kung Fu Hustle 2004 1080p x264.mkv): uploaded already as video 1319),
        %(Would upload "Shrek" (Shrek.2001.1080p.BluRay.x264.YIFY.mp4) with 1 subtitle file),
        %(Would upload "There's Something About Mary" (Theres.Something.About.Mary.EXTENDED.CUT.1998.1080p.BrRip.x264.YIFY.mp4) with no subtitles)
      ])
      expect(status.exitstatus).to eq(0)
      expect(File.read(File.join(@folder, "synthwaves-uploaded.log")).lines.size).to eq(1)
    end

    # macOS keeps some folders from a terminal that has not been given access
    # (~/Movies/TV, the TV app's library). A sandbox that refuses to open one
    # folder fails the same way: Operation not permitted.
    it "names a folder it is not permitted to read, and lists the videos in the rest" do
      skip "needs macOS sandbox-exec" unless File.executable?("/usr/bin/sandbox-exec")
      movie("Shrek (2001) [1080p]/Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
      locked = place("TV/Media").tap { |dir| FileUtils.mkdir_p(dir) }
      refuse = %((version 1)(allow default)(deny file-read-data (subpath "#{File.realpath(File.dirname(locked))}")))

      out, _err, status = Open3.capture3(no_credentials, "/usr/bin/sandbox-exec", "-p", refuse, RbConfig.ruby, script, @folder, "--dry-run")

      expect(out.lines.map(&:chomp)).to eq([
        "Skipping the folder #{File.join(@folder, "TV")}: it can't be read (Operation not permitted)",
        %(Would upload "Shrek" (Shrek.2001.1080p.BluRay.x264.YIFY.mp4) with no subtitles)
      ])
      expect(status.exitstatus).to eq(0)
    end
  end
end
