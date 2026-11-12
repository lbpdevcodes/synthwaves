require "tmpdir"
require "fileutils"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::SubtitleFiles do
  around do |example|
    Dir.mktmpdir do |root|
      @dir = File.join(root, "The Odyssey (2026) [1080p] [BluRay]")
      FileUtils.mkdir_p(@dir)
      @movie = write("The.Odyssey.2026.mp4", "frames")
      example.run
    end
  end

  def write(relative, contents)
    path = File.join(@dir, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
    path
  end

  def found = described_class.beside(@movie).map { |path| path.delete_prefix("#{@dir}/") }

  it "finds the subtitle files in a Subs folder beside the video" do
    write("Subs/English.srt", "english")
    write("Subs/Canadian.fre.srt", "french")

    expect(found).to eq(["Subs/Canadian.fre.srt", "Subs/English.srt"])
  end

  it "finds nothing beside a video that came without subtitles" do
    write("Poster.jpg", "jpeg")

    expect(found).to be_empty
  end

  it "finds the subtitle files beside the video that are named after it, and no others" do
    write("The.Odyssey.2026.en.srt", "english")
    write("The.Odyssey.2026.fr.vtt", "french")
    write("Another.Movie.srt", "someone else's")

    expect(found).to eq(["The.Odyssey.2026.en.srt", "The.Odyssey.2026.fr.vtt"])
  end

  it "leaves another episode whose name only starts like this one's" do
    episode = write("Show.S01E1.mkv", "frames")
    write("Show.S01E1.en.srt", "episode 1")
    write("Show.S01E10.en.srt", "episode 10")

    expect(described_class.beside(episode).map { |path| File.basename(path) }).to eq(["Show.S01E1.en.srt"])
  end

  it "sends a file once when the same subtitles sit beside the video and in Subs" do
    write("Subs/English.srt", "the same english")
    write("The.Odyssey.2026.srt", "the same english")

    expect(found).to eq(["Subs/English.srt"])
  end

  it "finds the subtitle files in the video's own folder inside Subs" do
    write("Subs/The.Odyssey.2026/2_English.srt", "english")
    write("Subs/Another.Episode/2_English.srt", "another episode's english")

    expect(found).to eq(["Subs/The.Odyssey.2026/2_English.srt"])
  end
end
