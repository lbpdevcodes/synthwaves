require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::SampleClip do
  it "calls a file whose name ends with the word sample a sample clip" do
    expect(described_class.reason("/Movies/Heat/heat.1995.1080p.bluray-grp.sample.mkv")).to eq("a sample clip")
  end

  it "leaves a video alone when sample is only a word in its title" do
    expect(described_class.reason("/Movies/Sample.People.2000.1080p.mkv")).to be_nil
  end
end
