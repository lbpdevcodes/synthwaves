require "rails_helper"

RSpec.describe SubtitleFilename do
  def named(filename, video_basename: "The.Odyssey.2026.1080p")
    described_class.new(filename, video_basename: video_basename)
  end

  it "names a file called after its language" do
    expect(named("English.srt")).to have_attributes(label: "English", language: "en", kind: "subtitles")
  end

  it "puts the other words of the name in parentheses after the language" do
    expect(named("Canadian.fre.srt")).to have_attributes(label: "French (Canadian)", language: "fr")
  end

  it "keeps a qualifier of several words whole" do
    expect(named("Latin American.spa.srt")).to have_attributes(label: "Spanish (Latin American)", language: "es")
  end

  it "files subtitles for the deaf and hard of hearing as captions" do
    expect(named("SDH.eng.HI.srt")).to have_attributes(label: "English (SDH)", language: "en", kind: "captions")
  end

  it "calls a file named after the video plain Subtitles" do
    file = named("The.Odyssey.2026.1080p.BluRay.srt", video_basename: "The.Odyssey.2026.1080p.BluRay")

    expect(file).to have_attributes(label: "Subtitles", language: nil)
  end

  it "reads the language a file adds to the video's own name" do
    expect(named("Heat.1995.en.srt", video_basename: "Heat.1995")).to have_attributes(label: "English", language: "en")
  end

  it "does not strip a video's name from a longer word that only starts with it" do
    expect(named("Aliens.en.srt", video_basename: "Alien")).to have_attributes(label: "English (Aliens)", language: "en")
  end

  it "ignores the track number some releases put before the language" do
    expect(named("2_English.srt")).to have_attributes(label: "English", language: "en")
  end

  it "knows common languages by the three-letter codes releases use" do
    languages = %w[ger.srt jpn.srt chi.srt por.srt dut.srt].map { |name| named(name).language }

    expect(languages).to eq(%w[de ja zh pt nl])
  end

  it "reads HI as hearing impaired, not Hindi" do
    expect(named("HI.eng.srt")).to have_attributes(label: "English (SDH)", language: "en", kind: "captions")
  end

  it "labels a file that names no language by its own words" do
    expect(named("Director.Commentary.srt")).to have_attributes(label: "Director Commentary", language: nil)
  end
end
