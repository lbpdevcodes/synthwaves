require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::VideoTitle do
  def title(filename) = described_class.from(filename)

  it "reads the words of a name joined by dots, up to the release year" do
    expect(title("Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv")).to eq("Dazed and Confused")
  end

  it "reads a name spaced out with spaces or underscores" do
    expect([title("Kung Fu Hustle 2004 1080p x264.mkv"), title("Half_Baked_1998_1080p.mkv")]).to eq(["Kung Fu Hustle", "Half Baked"])
  end

  it "stops at a year in brackets" do
    expect(title("Kung Fu Hustle (2004) [1080p].mkv")).to eq("Kung Fu Hustle")
  end

  it "capitalises each word, keeping short joining words lowercase after the first" do
    expect([title("happy.gilmore.1996.1080p.mkv"), title("The.Legend.Of.Ron.Burgundy.2004.mp4")]).to eq(["Happy Gilmore", "The Legend of Ron Burgundy"])
  end

  it "drops the edition words that come before the year" do
    expect(title("Theres.Something.About.Mary.EXTENDED.CUT.1998.1080p.BrRip.x264.YIFY.mp4")).to eq("Theres Something About Mary")
  end

  it "keeps a year that is part of the title" do
    expect([title("Blade.Runner.2049.2017.1080p.mkv"), title("1917.2019.1080p.mkv")]).to eq(["Blade Runner 2049", "1917"])
  end

  it "stops at the first quality tag when the name has no year" do
    expect(title("Clip.1080p.WEB-DL.x264.mkv")).to eq("Clip")
  end

  it "uses the whole name when it has no year or quality tag" do
    expect(title("home movie.mp4")).to eq("Home Movie")
  end
end
