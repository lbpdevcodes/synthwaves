require "tmpdir"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::UploadLog do
  around do |example|
    Dir.mktmpdir do |folder|
      @folder = folder
      example.run
    end
  end

  let(:file) { File.join(@folder, "synthwaves-uploaded.log") }

  it "remembers a filed video on the next run" do
    described_class.in(@folder).record("Shrek", 1320)

    expect(described_class.in(@folder).filed("Shrek")).to eq(1320)
  end

  it "reads the log tmp/upload_movies.sh writes" do
    File.write(file, "Kung Fu Hustle\tvideo 1319\t2026-11-11 21:40:00\n")

    expect(described_class.in(@folder).filed("Kung Fu Hustle")).to eq(1319)
  end

  it "keeps what it already holds when it records another video" do
    File.write(file, "Kung Fu Hustle\tvideo 1319\t2026-11-11 21:40:00\n")

    described_class.in(@folder).record("Shrek", 1320)

    expect(%w[Kung\ Fu\ Hustle Shrek].map { |title| described_class.in(@folder).filed(title) }).to eq([1319, 1320])
  end

  it "knows nothing of a title it never filed, or of a folder with no log" do
    expect(described_class.in(@folder).filed("Shrek")).to be_nil
  end
end
