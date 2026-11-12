require "tmpdir"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::TitleFixes do
  around do |example|
    Dir.mktmpdir do |folder|
      @folder = folder
      example.run
    end
  end

  def fixes = described_class.in(@folder)

  def write(contents) = File.write(File.join(@folder, "synthwaves-titles.txt"), contents)

  it "replaces a title the folder's titles file corrects" do
    write("Theres Something About Mary = There's Something About Mary\n")

    expect(fixes.apply("Theres Something About Mary")).to eq("There's Something About Mary")
  end

  it "leaves a title the file does not mention as it is" do
    write("Theres Something About Mary = There's Something About Mary\n")

    expect(fixes.apply("Shrek")).to eq("Shrek")
  end

  it "skips blank lines and # comments" do
    write("# fixes\n\nAnchorman the Legend of Ron Burgundy = Anchorman: The Legend of Ron Burgundy\n")

    expect(fixes.apply("Anchorman the Legend of Ron Burgundy")).to eq("Anchorman: The Legend of Ron Burgundy")
  end

  it "changes nothing when the folder has no titles file" do
    expect(fixes.apply("Shrek")).to eq("Shrek")
  end
end
