require "tmpdir"
require "stringio"
require "fileutils"
require_relative "../../../../lib/cli/video_import"

module FolderImportFakes
  # Files a video as the server would, failing for the titles it is told to.
  class Importer
    attr_reader :calls

    def initialize(failing: [])
      @failing = failing
      @calls = []
    end

    def call(path, title:)
      @calls << [File.basename(path), title]
      raise VideoImport::Error, "connection to synthwaves.fm failed: Connection reset by peer" if @failing.include?(title)

      {"id" => 1320 + @calls.size, "title" => title, "status" => "processing"}
    end
  end

  # Adds subtitle files to a video, refusing the file names it is told to.
  class SubtitleUpload
    attr_reader :calls, :paths

    def initialize(refusing: [])
      @refusing = refusing
      @calls = []
      @paths = []
    end

    def call(video_id, paths)
      @paths.concat(paths)
      @calls << [video_id, paths.map { |path| [File.basename(path), File.exist?(path)] }]
      paths.map { |path| File.basename(path) }.select { |name| @refusing.include?(name) }.map { |name| "#{name}: rejected (422)" }
    end
  end

  # The text tracks inside each video, by file name.
  class EmbeddedSubtitles
    def initialize(tracks = {}) = @tracks = tracks

    def names(path) = @tracks.fetch(File.basename(path), [])

    def extract(path, dir) = names(path).map { |name| File.join(dir, "#{name}.srt").tap { |srt| File.write(srt, name) } }
  end
end

RSpec.describe VideoImport::FolderImport do
  let(:out) { StringIO.new }
  let(:importer) { FolderImportFakes::Importer.new }
  let(:subtitle_upload) { FolderImportFakes::SubtitleUpload.new }
  let(:embedded) { FolderImportFakes::EmbeddedSubtitles.new }

  around do |example|
    Dir.mktmpdir do |folder|
      @folder = folder
      example.run
    end
  end

  def place(relative, contents = "a movie")
    File.join(@folder, relative).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end
  end

  def folder_import = described_class.new(folder: @folder, out: out, importer: importer, subtitle_upload: subtitle_upload, embedded: embedded)

  it "uploads each finished video under the title its file name gives, in path order" do
    place("Shrek (2001) [1080p]/Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
    place("Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv")

    folder_import.call

    expect(importer.calls).to eq([["Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv", "Dazed and Confused"], ["Shrek.2001.1080p.BluRay.x264.YIFY.mp4", "Shrek"]])
  end

  it "remembers each filed video, so the next run skips it" do
    place("Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
    folder_import.call

    folder_import.call

    expect(importer.calls.size).to eq(1)
    expect(out.string).to include(%(Skipping "Shrek" (Shrek.2001.1080p.BluRay.x264.YIFY.mp4): uploaded already as video 1321))
  end

  it "skips a video that is still downloading, and says so" do
    place("Anchorman.2004.1080p.BrRip.x264.YIFY.mp4.part")

    folder_import.call

    expect(importer.calls).to be_empty
    expect(out.string).to include(%(Skipping "Anchorman" (Anchorman.2004.1080p.BrRip.x264.YIFY.mp4): still downloading))
  end

  it "uploads a release and skips the sample clip that came with it, which takes the same title" do
    place("Sword of the Stranger 2007 BRRip XvidHD 720p-NPW/Sword of the Stranger 2007 BRRip XvidHD 720p-NPW-Sample.avi")
    place("Sword of the Stranger 2007 BRRip XvidHD 720p-NPW/Sword of the Stranger 2007 BRRip XvidHD 720p-NPW.avi")

    folder_import.call

    expect(importer.calls).to eq([["Sword of the Stranger 2007 BRRip XvidHD 720p-NPW.avi", "Sword of the Stranger"]])
    expect(out.string).to include(%(Skipping "Sword of the Stranger" (Sword of the Stranger 2007 BRRip XvidHD 720p-NPW-Sample.avi): a sample clip))
  end

  it "sends the subtitle files beside a video once the server has filed it" do
    place("Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
    place("Shrek.2001.1080p.BluRay.x264.YIFY.srt", "1\n")

    folder_import.call

    expect(subtitle_upload.calls).to eq([[1321, [["Shrek.2001.1080p.BluRay.x264.YIFY.srt", true]]]])
  end

  it "sends the text tracks inside a video that has no subtitle files beside it, then deletes them" do
    place("Half.Baked.1998.1080p.mkv")
    tracks = FolderImportFakes::EmbeddedSubtitles.new("Half.Baked.1998.1080p.mkv" => ["eng", "SDH.eng"])
    folder_import = described_class.new(folder: @folder, out: out, importer: importer, subtitle_upload: subtitle_upload, embedded: tracks)

    folder_import.call

    expect(subtitle_upload.calls).to eq([[1321, [["eng.srt", true], ["SDH.eng.srt", true]]]])
    expect(subtitle_upload.paths.select { |path| File.exist?(path) }).to be_empty
  end

  it "keeps a video it filed in the log when its subtitles are refused, and flags it" do
    place("Shrek.2001.1080p.BluRay.x264.YIFY.mp4")
    place("Shrek.2001.1080p.BluRay.x264.YIFY.srt", "1\n")
    refusing = FolderImportFakes::SubtitleUpload.new(refusing: ["Shrek.2001.1080p.BluRay.x264.YIFY.srt"])
    folder_import = described_class.new(folder: @folder, out: out, importer: importer, subtitle_upload: refusing, embedded: embedded)

    expect(folder_import.call).to be(false)
    expect(VideoImport::UploadLog.in(@folder).filed("Shrek")).to eq(1321)
    expect(out.string).to include(%(Check: "Shrek" is up as video 1321, but Shrek.2001.1080p.BluRay.x264.YIFY.srt: rejected (422); add it on the video's edit page))
  end

  it "carries on after a video fails, and reports what was uploaded, skipped and failed" do
    place("Anchorman.2004.1080p.mp4.part")
    place("Dazed.and.Confused.1993.1080p.mkv")
    place("Shrek.2001.1080p.mp4")
    importer = FolderImportFakes::Importer.new(failing: ["Dazed and Confused"])
    folder_import = described_class.new(folder: @folder, out: out, importer: importer, subtitle_upload: subtitle_upload, embedded: embedded)

    expect(folder_import.call).to be(false)
    expect(out.string.lines.last(3).map(&:chomp)).to eq([
      %(Uploaded 1: "Shrek" (video 1322)),
      %(Skipped 1: "Anchorman" (still downloading)),
      %(Failed 1: "Dazed and Confused" (connection to synthwaves.fm failed: Connection reset by peer))
    ])
  end

  it "says it succeeded when every ready video went up" do
    place("Shrek.2001.1080p.mp4")

    expect(folder_import.call).to be(true)
  end

  it "leaves out hidden files, like the ._ copies macOS writes on other drives" do
    place("Shrek.2001.1080p.mp4")
    place("._Shrek.2001.1080p.mp4")

    folder_import.call(dry_run: true)

    expect(out.string).to eq(%(Would upload "Shrek" (Shrek.2001.1080p.mp4) with no subtitles\n))
  end

  it "names a folder it has no permission to read, and carries on with the rest" do
    place("Shrek.2001.1080p.mp4")
    locked = File.dirname(place("Locked/Elf.2003.1080p.mp4"))
    File.chmod(0o000, locked)

    folder_import.call(dry_run: true)

    expect(out.string.lines.map(&:chomp)).to eq([
      "Skipping the folder #{locked}: it can't be read (Permission denied)",
      %(Would upload "Shrek" (Shrek.2001.1080p.mp4) with no subtitles)
    ])
  ensure
    File.chmod(0o755, locked) if locked
  end

  it "does not follow a link to another folder" do
    place("Shrek.2001.1080p.mp4")
    File.symlink(@folder, File.join(@folder, "again"))

    folder_import.call(dry_run: true)

    expect(out.string).to eq(%(Would upload "Shrek" (Shrek.2001.1080p.mp4) with no subtitles\n))
  end

  it "uploads nothing on a dry run" do
    place("Shrek.2001.1080p.mp4")

    folder_import.call(dry_run: true)

    expect(importer.calls).to be_empty
    expect(out.string).to eq(%(Would upload "Shrek" (Shrek.2001.1080p.mp4) with no subtitles\n))
  end
end
