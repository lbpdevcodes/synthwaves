require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::UploadLimit do
  let(:source) { Struct.new(:filename, :byte_size) }

  it "fits a file up to 5 GB in one upload, the most storage takes in one PUT" do
    limit = described_class.new

    expect([limit.fits?(source.new("Heat.mp4", 5_000_000_000)), limit.fits?(source.new("Heat.mp4", 5_000_000_001))]).to eq([true, false])
  end
end
