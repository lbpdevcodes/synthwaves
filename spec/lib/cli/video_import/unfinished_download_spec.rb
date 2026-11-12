require "tmpdir"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::UnfinishedDownload do
  around do |example|
    Dir.mktmpdir do |folder|
      @movie = File.join(folder, "Shrek.2001.1080p.mp4")
      example.run
    end
  end

  it "finds nothing unfinished about a whole file nothing is writing" do
    File.write(@movie, "a whole movie")

    expect(described_class.reason(@movie)).to be_nil
  end

  it "says a video is still downloading while its .part file is there" do
    File.write("#{@movie}.part", "half a movie")

    expect(described_class.reason(@movie)).to eq("still downloading")
  end

  it "says a video is still being written while another program has it open to write" do
    File.open(@movie, "a") do |writing|
      writing.write("half a movie")

      expect(described_class.reason(@movie)).to eq("still being written")
    end
  end
end
