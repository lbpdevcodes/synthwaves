require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::UploadLimit do
  let(:source) { Struct.new(:filename, :byte_size) }

  it "fits a file up to 5 GB, the most storage takes in one upload" do
    limit = described_class.new

    expect([limit.fits?(source.new("Heat.mp4", 5_000_000_000)), limit.fits?(source.new("Heat.mp4", 5_000_000_001))]).to eq([true, false])
  end

  it "says how far over the limit a file is" do
    limit = described_class.new

    expect(limit.over(source.new("Life Is Beautiful.mp4", 8_412_345_678)))
      .to eq("Life Is Beautiful.mp4 is 8.4 GB, over the 5.0 GB storage takes in one upload")
  end
end
