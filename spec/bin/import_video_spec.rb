require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"
require_relative "../support/video_clips"

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
end
