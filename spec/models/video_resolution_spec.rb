require "rails_helper"

RSpec.describe VideoResolution do
  describe ".label" do
    it "has no label for a video missing a dimension" do
      expect([described_class.label(width: nil, height: 1080), described_class.label(width: 1920, height: nil)])
        .to eq([nil, nil])
    end

    it "calls a video under 720 lines SD" do
      expect(described_class.label(width: 640, height: 480)).to eq("SD")
    end

    it "calls a 1280×720 video 720p" do
      expect(described_class.label(width: 1280, height: 720)).to eq("720p")
    end

    it "calls a 1920×1080 video 1080p" do
      expect(described_class.label(width: 1920, height: 1080)).to eq("1080p")
    end

    it "calls a 3840×2160 video 4K" do
      expect(described_class.label(width: 3840, height: 2160)).to eq("4K")
    end

    it "goes by the width of a letterboxed film" do
      expect(described_class.label(width: 1920, height: 800)).to eq("1080p")
    end

    it "goes by the height of a 4:3 transfer" do
      expect(described_class.label(width: 1440, height: 1080)).to eq("1080p")
    end

    it "keeps a slightly cropped encode in its bucket" do
      expect([described_class.label(width: 1916, height: 1036), described_class.label(width: 3840, height: 1600)])
        .to eq(%w[1080p 4K])
    end
  end
end
