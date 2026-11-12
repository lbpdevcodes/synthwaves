require "webmock/rspec"
require "tmpdir"
require "stringio"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::MultipartUpload do
  let(:host) { "https://synthwaves.test" }
  let(:out) { StringIO.new }
  let(:api) { VideoImport::API.new(host: host, client_id: "bc_id", secret_key: "secret") }
  let(:waits) { [] }
  let(:upload) { described_class.new(api: api, out: out, wait: ->(seconds) { waits << seconds }) }
  let(:contents) { "a" * 10 + "b" * 10 + "c" * 5 }
  let(:ids) { {signed_id: "signed-blob", upload_id: "upload-1"} }

  around do |example|
    Dir.mktmpdir do |dir|
      @movie = File.join(dir, "City of God.mp4")
      File.binwrite(@movie, contents)
      example.run
    end
  end

  def source = VideoImport::SourceFile.at(@movie)

  def slice(number) = contents.byteslice((number - 1) * 10, 10)

  def part_url(number) = "https://storage.test/bucket/key?partNumber=#{number}"

  def stub_start
    stub_request(:post, "#{host}/api/v1/auth/token").to_return(body: JSON.generate(token: "token"))
    stub_request(:post, "#{host}/api/import/multipart_upload")
      .to_return(status: 201, body: JSON.generate(ids.merge(part_size: 10)))
  end

  def stub_presign
    stub_request(:post, "#{host}/api/import/multipart_upload/parts").to_return do |request|
      number = JSON.parse(request.body).fetch("part_number")
      {status: 201, body: JSON.generate(url: part_url(number), headers: {"Content-MD5" => Digest::MD5.base64digest(slice(number))})}
    end
  end

  def stub_parts
    (1..3).each { |number| stub_request(:put, part_url(number)).to_return(headers: {"ETag" => "\"etag-#{number}\""}) }
  end

  def stub_completion = stub_request(:post, "#{host}/api/import/multipart_upload/completion").to_return(body: JSON.generate(signed_id: "signed-blob"))

  def stub_abort = stub_request(:delete, %r{\A#{host}/api/import/multipart_upload\?}).to_return(status: 204)

  def stub_whole_upload
    stub_start
    stub_presign
    stub_parts
    stub_completion
  end

  it "puts each part's exact bytes to its own presigned URL with the signed headers" do
    stub_whole_upload

    upload.store(source)

    (1..3).each do |number|
      expect(WebMock).to have_requested(:put, part_url(number))
        .with(body: slice(number), headers: {"Content-MD5" => Digest::MD5.base64digest(slice(number)), "Content-Length" => slice(number).bytesize.to_s})
    end
  end

  it "has the server sign each part's own size and checksum, the last part being what is left" do
    stub_whole_upload

    upload.store(source)

    [[1, 10], [2, 10], [3, 5]].each do |number, size|
      expect(a_request(:post, "#{host}/api/import/multipart_upload/parts").with(body: ids.merge(
        part_number: number, byte_size: size, checksum: Digest::MD5.base64digest(slice(number))
      ))).to have_been_made.once
    end
  end

  it "shows one meter for the whole file, counting up through the parts to 100% once" do
    stub_whole_upload

    upload.store(source)

    expect(out.string).to eq("\rUploading City of God.mp4:  40%\rUploading City of God.mp4:  80%\rUploading City of God.mp4: 100%\n")
  end

  describe "when a part does not go up" do
    def presigned(number) = a_request(:post, "#{host}/api/import/multipart_upload/parts").with(body: hash_including("part_number" => number))

    it "sends the part again with a freshly signed URL, after a pause, and carries on" do
      stub_whole_upload
      stub_request(:put, part_url(2)).to_raise(Errno::ECONNRESET).then.to_return(headers: {"ETag" => "\"etag-2\""})

      expect(upload.store(source)).to eq("signed-blob")
      expect(presigned(2)).to have_been_made.twice
      expect(waits.size).to eq(1)
    end

    it "gives up after three tries, has the server throw away the parts sent, and names the part" do
      stub_whole_upload
      stub_abort
      stub_request(:put, part_url(2)).to_return(status: 500, body: "<Error><Code>InternalError</Code></Error>")

      expect { upload.store(source) }.to raise_error(VideoImport::Error,
        "part 2 of City of God.mp4 did not go up after 3 tries: storage rejected the upload (500): InternalError")
      expect(a_request(:delete, "#{host}/api/import/multipart_upload").with(query: ids)).to have_been_made.once
      expect(a_request(:post, "#{host}/api/import/multipart_upload/completion")).not_to have_been_made
    end

    it "throws away the parts sent when the upload is interrupted (Ctrl-C)" do
      stub_whole_upload
      stub_abort
      stub_request(:put, part_url(2)).to_raise(Interrupt)

      expect { upload.store(source) }.to raise_error(Interrupt)
      expect(a_request(:delete, "#{host}/api/import/multipart_upload").with(query: ids)).to have_been_made.once
      expect(presigned(2)).to have_been_made.once
    end

    it "still names the part when throwing the parts away fails too, and says what was left behind" do
      stub_whole_upload
      stub_request(:delete, %r{\A#{host}/api/import/multipart_upload\?}).to_return(status: 502)
      stub_request(:put, part_url(2)).to_return(status: 500, body: "<Error><Code>InternalError</Code></Error>")

      expect { upload.store(source) }.to raise_error(VideoImport::Error, /\Apart 2 of City of God.mp4 did not go up/)
      expect(out.string).to include("The parts sent so far stay in storage: throwing away the parts failed (502)")
    end
  end

  it "has the server join the parts by the ETags storage gave them, and hands back the blob to file" do
    stub_whole_upload

    expect(upload.store(source)).to eq("signed-blob")
    expect(WebMock).to have_requested(:post, "#{host}/api/import/multipart_upload/completion").with(body: ids.merge(
      parts: [{part_number: 1, etag: "\"etag-1\""}, {part_number: 2, etag: "\"etag-2\""}, {part_number: 3, etag: "\"etag-3\""}]
    ))
  end
end
