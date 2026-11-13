require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::FiledAs do
  # Stands in for VideoImport::Importer, keeping what each call asked for.
  let(:importer) do
    Class.new do
      attr_reader :calls

      def call(path, **video) = (@calls ||= []) << [path, video]
    end.new
  end

  it "files each video with the run's fields beside its own" do
    described_class.new(importer, video_type: "movie", genres: ["comedy"]).call("Elf.mkv", title: "Elf")

    expect(importer.calls).to eq([["Elf.mkv", {video_type: "movie", genres: ["comedy"], title: "Elf"}]])
  end
end
