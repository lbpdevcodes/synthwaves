require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::EpisodeNumber do
  def episode(filename) = described_class.from("/TV/#{filename}")

  it "reads the season and episode from S01E02" do
    expect(episode("The.Wire.S01E02.720p.HDTV.mkv")).to eq(season_number: 1, episode_number: 2)
  end

  it "reads them when a dot parts the season from the episode" do
    expect(episode("law.and.order.svu.s01.e07.uncilvilized.dvdrip.xvid.ac3.mp4")).to eq(season_number: 1, episode_number: 7)
  end

  it "reads them when a space or an underscore parts the season from the episode" do
    expect([episode("South Park S03 E11.mp4"), episode("south_park_s03_e11.mp4")]).to all(eq(season_number: 3, episode_number: 11))
  end

  it "reads them from 2x05" do
    expect(episode("The.Office.2x05.Halloween.mkv")).to eq(season_number: 2, episode_number: 5)
  end

  it "reads no episode from a picture size" do
    expect(episode("Heat.1995.1920x1080.x264.mkv")).to eq({})
  end

  it "reads no episode from an aspect ratio" do
    expect([episode("Heat.1995.DVDRip.16x9.XviD.avi"), episode("Heat.1995.4x3.DVDRip.avi")]).to all(eq({}))
  end
end
