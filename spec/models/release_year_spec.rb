require "rails_helper"

RSpec.describe ReleaseYear do
  describe ".from" do
    it "reads the year a release name puts before its quality tags" do
      expect(described_class.from("Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mp4")).to eq(1993)
    end

    it "is nil when the name carries no year" do
      expect(described_class.from("Zombieland.BluRay.1080p.x264.5.1.Judas.mp4")).to be_nil
    end

    it "takes the last year before the tags, since a title can hold a year" do
      expect(described_class.from("Blade.Runner.2049.2017.1080p.BluRay.mkv")).to eq(2017)
    end

    it "reads a year that opens the name as the title" do
      expect(described_class.from("1917.2019.1080p.mkv")).to eq(2019)
      expect(described_class.from("1917.mkv")).to be_nil
    end

    it "reads a year in brackets, between spaces" do
      expect(described_class.from("American History X (1998) 1080p BluRay 5.1Ch x265 HEVC SUJAIDR.mp4")).to eq(1998)
    end

    it "ignores a year after the quality tags" do
      expect(described_class.from("Heat.1080p.BluRay.x264.2010.mkv")).to be_nil
    end
  end
end
