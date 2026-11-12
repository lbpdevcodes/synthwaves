require "tmpdir"
require "stringio"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::FilePart do
  let(:contents) { Random.new(7).bytes(100 * 1024) }

  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, "City of God.mp4")
      File.binwrite(@path, contents)
      example.run
    end
  end

  def parts = described_class.split(VideoImport::SourceFile.at(@path), 40 * 1024)

  # Net::HTTP streams a sized body with IO.copy_stream, which reads in
  # buffered chunks until the IO says it has no more.
  def streamed(part) = part.open { |io| StringIO.new(String.new(encoding: Encoding::BINARY)).tap { |sink| IO.copy_stream(io, sink) }.string }

  it "splits a file into parts of the size given, the last one holding what is left" do
    expect(parts.map { |part| [part.number, part.offset, part.byte_size] })
      .to eq([[1, 0, 40 * 1024], [2, 40 * 1024, 40 * 1024], [3, 80 * 1024, 20 * 1024]])
  end

  it "streams exactly its own stretch of the file, the way Net::HTTP reads it" do
    expect(parts.map { |part| streamed(part) }).to eq([contents[0, 40 * 1024], contents[40 * 1024, 40 * 1024], contents[80 * 1024..]])
  end

  it "checksums only its own stretch" do
    expect(parts[1].checksum).to eq(Digest::MD5.base64digest(contents[40 * 1024, 40 * 1024]))
  end
end
