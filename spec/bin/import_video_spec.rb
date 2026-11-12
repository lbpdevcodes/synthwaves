require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"
require "socket"
require "json"
require_relative "../support/video_clips"

# Plays synthwaves.fm and its storage for one run of the script: answers each
# request by path, files a video sent with its details ready, and refuses a
# subtitle file whose name mentions "notes".
class FakeSynthwaves
  attr_reader :requests

  def initialize
    @server = TCPServer.new("127.0.0.1", 0)
    @requests = []
    @thread = Thread.new { loop { serve(@server.accept) } }
  end

  def url = "http://127.0.0.1:#{@server.addr[1]}"

  def stop
    @thread.kill
    @server.close
  end

  private

  def serve(client)
    method, path = client.gets.split
    headers = read_headers(client)
    body = client.read(headers.fetch("content-length", "0").to_i)
    @requests << [method, path, body]
    status, json = reply(method, path, body)
    payload = JSON.generate(json)
    client.write("HTTP/1.1 #{status} OK\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
  ensure
    client.close
  end

  def read_headers(client)
    lines = []
    while (line = client.gets) && line != "\r\n"
      lines << line
    end
    lines.to_h { |line| line.split(": ", 2).then { |name, value| [name.downcase, value.strip] } }
  end

  def reply(method, path, body)
    case [method, path]
    in ["POST", "/api/v1/auth/token"] then [200, {token: "token"}]
    in ["POST", "/api/import/direct_uploads"] then [201, {signed_id: "blob", direct_upload: {url: "#{url}/storage", headers: {}}}]
    in ["PUT", "/storage"] then [200, {}]
    in ["POST", "/api/import/videos"] then [201, {id: 7, title: "Heat", status: JSON.parse(body).key?("details") ? "ready" : "processing"}]
    in ["POST", "/api/import/videos/7/subtitles"] then subtitle_reply(JSON.parse(body).fetch("filename"))
    end
  end

  def subtitle_reply(filename)
    return [422, {error: "#{filename}: no subtitle cues found"}] if filename.include?("notes")

    [201, {id: 1, label: File.basename(filename, ".*"), language: nil, kind: "subtitles"}]
  end
end

RSpec.describe "bin/import_video" do
  let(:script) { File.expand_path("../../bin/import_video", __dir__) }
  let(:credentials) { {"SYNTHWAVES_CLIENT_ID" => "bc_id", "SYNTHWAVES_SECRET_KEY" => "secret"} }

  def run_script(*args, env: credentials)
    Open3.capture3(env, RbConfig.ruby, script, *args)
  end

  it "prints its usage and fails when no file is given" do
    _out, err, status = run_script

    expect(err).to include("Usage: bin/import_video PATH")
    expect(status.exitstatus).to eq(1)
  end

  it "names the missing credentials and fails" do
    _out, err, status = run_script("Heat.mkv", env: {"SYNTHWAVES_CLIENT_ID" => nil, "SYNTHWAVES_SECRET_KEY" => nil})

    expect(err).to include("import_video: set SYNTHWAVES_CLIENT_ID and SYNTHWAVES_SECRET_KEY")
    expect(status.exitstatus).to eq(1)
  end

  it "names a file that does not exist and fails" do
    missing = File.join(Dir.tmpdir, "no-such-movie-#{Process.pid}.mkv")

    _out, err, status = run_script(missing)

    expect(err).to include("import_video: no such file: #{missing}")
    expect(status.exitstatus).to eq(1)
  end

  context "with a file ffprobe cannot read" do
    let(:dir) { Dir.mktmpdir }
    let(:notes) { File.join(dir, "notes.mkv").tap { |path| File.write(path, "not a video") } }
    let(:dead_host) { "http://127.0.0.1:9" }

    after { FileUtils.rm_rf(dir) }

    it "checks the file with ffprobe before uploading anything" do
      skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools?
      _out, err, status = run_script(notes, "--host", dead_host)

      expect(err).to include("import_video: could not read #{notes} as a video")
      expect(status.exitstatus).to eq(1)
    end

    it "uploads it untouched with --no-encode, leaving conversion to the server" do
      _out, err, status = run_script(notes, "--no-encode", "--host", dead_host)

      expect(err).to include("import_video: connection to 127.0.0.1 failed")
      expect(status.exitstatus).to eq(1)
    end
  end

  it "names an option it cannot read and fails" do
    _out, err, status = run_script("Heat.mkv", "--season", "one")

    expect(err).to include("import_video: invalid argument: --season one")
    expect(status.exitstatus).to eq(1)
  end

  context "with subtitle files beside the video" do
    let(:dir) { Dir.mktmpdir }
    let(:movie) { File.join(dir, "Heat.mkv").tap { |path| File.write(path, "not a video") } }
    let(:dead_host) { "http://127.0.0.1:9" }

    before do
      FileUtils.mkdir_p(File.join(dir, "Subs"))
      File.write(File.join(dir, "Subs", "English.srt"), "english")
      File.write(File.join(dir, "Subs", "Canadian.fre.srt"), "french")
    end

    after { FileUtils.rm_rf(dir) }

    it "names the subtitles it will send before it uploads anything" do
      out, _err, _status = run_script(movie, "--no-encode", "--host", dead_host)

      expect(out).to include("Subtitles: Canadian.fre.srt, English.srt\n")
    end

    it "sends none with --no-subtitles" do
      out, _err, _status = run_script(movie, "--no-subtitles", "--no-encode", "--host", dead_host)

      expect(out).to include("Subtitles: none\n")
    end

    it "sends only the files named with --subtitle" do
      chosen = File.join(dir, "Heat.director-commentary.srt").tap { |path| File.write(path, "commentary") }

      out, _err, _status = run_script(movie, "--subtitle", chosen, "--no-encode", "--host", dead_host)

      expect(out).to include("Subtitles: Heat.director-commentary.srt\n")
    end

    it "names a --subtitle file that does not exist and fails before uploading anything" do
      missing = File.join(dir, "Heat.nope.srt")

      _out, err, status = run_script(movie, "--subtitle", missing, "--no-encode", "--host", dead_host)

      expect(err).to include("import_video: no such subtitle file: #{missing}")
      expect(err).not_to include("connection to")
      expect(status.exitstatus).to eq(1)
    end

    it "finds the subtitles beside the original file when it encodes a copy elsewhere" do
      skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools?
      clip = VideoClips.mpeg4_surround(dir)
      File.write(File.join(dir, "clip.en.srt"), "the clip's own english")

      out, _err, _status = run_script(clip, "--host", dead_host)

      expect(out).to include("Subtitles: Canadian.fre.srt, English.srt, clip.en.srt\n")
      expect(out).to include("Encoding clip.mkv")
    end
  end

  context "against a server" do
    let(:dir) { Dir.mktmpdir }
    let(:movie) { File.join(dir, "Heat.mkv").tap { |path| File.write(path, "not a video") } }
    let(:server) { FakeSynthwaves.new }

    after do
      server.stop
      FileUtils.rm_rf(dir)
    end

    def subs(name, contents) = File.join(dir, "Subs", name).tap { |path| FileUtils.mkdir_p(File.dirname(path)) && File.write(path, contents) }

    it "files a video the server keeps as it is with its details and thumbnail, so the server never downloads it" do
      skip "needs ffmpeg and ffprobe on PATH" unless VideoClips.tools?
      clip = VideoClips.h264(dir)

      out, err, status = run_script(clip, "--no-subtitles", "--host", server.url)

      expect(out).to include(%(Filed "Heat" as video 7 (ready).\nIt is ready to watch: #{server.url}/videos/7\n))
      stored = server.requests.select { |method, *| method == "PUT" }.map { |*, body| body.byteslice(0, 2).bytes }
      filed = JSON.parse(server.requests.find { |_, path, _| path == "/api/import/videos" }.last)
      expect(stored).to eq([File.binread(clip, 2).bytes, [0xFF, 0xD8]])
      expect(filed).to include("thumbnail_signed_blob_id" => "blob")
      expect(filed["details"]).to include("video_codec" => "h264", "audio_codec" => "aac", "audio_channels" => 2, "width" => 320, "height" => 240)
      expect([err, status.exitstatus]).to eq(["", 0])
    end

    it "sends each subtitle file once the video is filed" do
      subs("English.srt", "english")
      subs("Canadian.fre.srt", "french")

      out, err, status = run_script(movie, "--no-encode", "--host", server.url)

      calls = server.requests.map { |method, path, _| "#{method} #{path}" }
      sent = server.requests.select { |_, path, _| path.end_with?("/subtitles") }.map { |*, body| JSON.parse(body)["filename"] }
      expect(calls.index("POST /api/import/videos")).to be < calls.index("POST /api/import/videos/7/subtitles")
      expect(sent).to eq(["Canadian.fre.srt", "English.srt"])
      expect(out).to include("Added subtitles: Canadian.fre\nAdded subtitles: English\n")
      expect(out).to include("It appears under Watch → Videos once the server has processed it: #{server.url}/videos/7\n")
      expect([err, status.exitstatus]).to eq(["", 0])
    end

    it "names a subtitle the server refused, says where to add it, and fails" do
      subs("English.srt", "english")
      subs("notes.srt", "not subtitles")

      out, err, status = run_script(movie, "--no-encode", "--host", server.url)

      expect(out).to include("Filed \"Heat\" as video 7").and include("Added subtitles: English\n")
      expect(err).to include("import_video: could not add notes.srt: subtitle rejected (422): notes.srt: no subtitle cues found")
      expect(err).to include("import_video: video 7 is uploaded; add the missing subtitles at #{server.url}/videos/7/edit")
      expect(status.exitstatus).to eq(1)
    end
  end
end
