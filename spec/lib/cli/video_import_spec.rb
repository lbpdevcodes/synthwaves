require "webmock/rspec"
require "tmpdir"
require "stringio"
require_relative "../../../lib/cli/video_import"

RSpec.describe VideoImport::Importer do
  let(:host) { "https://synthwaves.test" }
  let(:upload_url) { "https://storage.test/bucket/blob-key?X-Amz-Signature=abc" }
  let(:signed_headers) { {"Content-Type" => "video/x-matroska", "Content-MD5" => "signed-md5"} }
  let(:out) { StringIO.new }
  let(:api) { VideoImport::API.new(host: host, client_id: "bc_id", secret_key: "secret") }
  let(:importer) { described_class.new(api: api, out: out, encoder: VideoImport::PassThrough.new) }
  let(:contents) { "frame" * 20 }

  around do |example|
    Dir.mktmpdir do |dir|
      @movie = File.join(dir, "Heat.mkv")
      File.binwrite(@movie, contents)
      example.run
    end
  end

  def stub_auth(*tokens, status: 200)
    replies = tokens.map { |token| {status: status, body: JSON.generate(token: token)} }
    stub_request(:post, "#{host}/api/v1/auth/token").to_return(*replies)
  end

  def stub_direct_upload(status: 201, body: {signed_id: "signed-blob", direct_upload: {url: upload_url, headers: signed_headers}})
    stub_request(:post, "#{host}/api/import/direct_uploads").to_return(status: status, body: JSON.generate(body))
  end

  def stub_storage(status: 200, body: "")
    stub_request(:put, upload_url).to_return(status: status, body: body)
  end

  def stub_register(status: 201, body: {id: 15, title: "Heat", folder: nil, status: "processing"})
    stub_request(:post, "#{host}/api/import/videos").to_return(status: status, body: JSON.generate(body))
  end

  def stub_successful_import
    stub_auth("token-1", "token-2")
    stub_direct_upload
    stub_storage
    stub_register
  end

  it "returns the video the server registered" do
    stub_successful_import

    expect(importer.call(@movie)).to include("id" => 15, "title" => "Heat", "status" => "processing")
  end

  it "puts the file's exact bytes to the presigned URL with the signed headers" do
    stub_successful_import

    importer.call(@movie)

    expect(WebMock).to have_requested(:put, upload_url)
      .with(body: contents, headers: signed_headers.merge("Content-Length" => contents.bytesize.to_s))
  end

  it "describes the file in the direct upload request" do
    stub_successful_import

    importer.call(@movie)

    expect(WebMock).to have_requested(:post, "#{host}/api/import/direct_uploads").with(body: {
      filename: "Heat.mkv", byte_size: contents.bytesize,
      checksum: Digest::MD5.base64digest(contents), content_type: "video/x-matroska"
    })
  end

  it "uploads the copy the encoder hands over, under the copy's name" do
    encoded = File.join(File.dirname(@movie), "Heat.mp4")
    File.binwrite(encoded, "encoded frames")
    encoder = Class.new do
      define_method(:prepare) { |_source, &upload| upload.call(VideoImport::SourceFile.at(encoded)) }
      define_method(:ready_details) { |_source| {} }
    end.new
    stub_successful_import

    described_class.new(api: api, out: out, encoder: encoder).call(@movie)

    expect(WebMock).to have_requested(:post, "#{host}/api/import/direct_uploads").with(body: hash_including(filename: "Heat.mp4"))
    expect(WebMock).to have_requested(:put, upload_url).with(body: "encoded frames")
  end

  it "files the uploaded blob with the title, folder, season and episode given" do
    stub_successful_import

    importer.call(@movie, title: "Pilot", folder_name: "Heat: The Series", season_number: 1, episode_number: 2)

    expect(WebMock).to have_requested(:post, "#{host}/api/import/videos").with(body: {
      signed_blob_id: "signed-blob", title: "Pilot", folder_name: "Heat: The Series", season_number: 1, episode_number: 2
    })
  end

  it "reports how much of the file has gone up" do
    stub_successful_import

    importer.call(@movie)

    expect(out.string).to start_with("\rUploading Heat.mkv:").and end_with("100%\n")
  end

  it "files the video with a token fetched after the upload, so a long upload cannot outlive it" do
    stub_successful_import

    importer.call(@movie)

    expect(WebMock).to have_requested(:post, "#{host}/api/import/videos").with(headers: {"Authorization" => "Bearer token-2"})
  end

  describe "when it cannot finish" do
    it "names a missing file without calling the server" do
      missing = File.join(File.dirname(@movie), "Nope.mkv")

      expect { importer.call(missing) }.to raise_error(VideoImport::Error, "no such file: #{missing}")
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    it "names the server's reason when the credentials are refused" do
      stub_request(:post, "#{host}/api/v1/auth/token")
        .to_return(status: 401, body: JSON.generate(error: "Invalid client_id or secret_key"))

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, "authentication failed (401): Invalid client_id or secret_key")
    end

    it "names the server's reason when it refuses the direct upload" do
      stub_auth("token-1")
      stub_direct_upload(status: 422, body: {error: "Validation failed: Byte size is too large"})

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, "direct upload rejected (422): Validation failed: Byte size is too large")
    end

    it "names the storage error when storage refuses the upload" do
      stub_auth("token-1")
      stub_direct_upload
      stub_storage(status: 403, body: "<Error><Code>AccessDenied</Code><Message>Request has expired</Message></Error>")

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, "storage rejected the upload (403): AccessDenied: Request has expired")
    end

    it "names the server's reason when it refuses to file the video" do
      stub_auth("token-1", "token-2")
      stub_direct_upload
      stub_storage
      stub_register(status: 422, body: {error: "Invalid signed blob ID"})

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, "video import rejected (422): Invalid signed blob ID")
    end

    it "names a connection to storage that drops mid-upload" do
      stub_auth("token-1")
      stub_direct_upload
      stub_request(:put, upload_url).to_raise(Errno::ECONNRESET)

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, /\Aconnection to storage.test failed: Connection reset by peer/)
    end

    it "gives up on a storage connection that drops, instead of re-sending the half-read file" do
      File.binwrite(@movie, "x" * 8_000_000)
      storage = TCPServer.new("127.0.0.1", 0)
      connections = Queue.new
      hang_up = Thread.new do
        loop do
          client = storage.accept
          connections << client
          client.readpartial(1024)
          client.close
        end
      end
      stub_auth("token-1")
      stub_direct_upload(body: {signed_id: "signed-blob", direct_upload: {url: "http://127.0.0.1:#{storage.addr[1]}/bucket/blob-key", headers: signed_headers}})
      WebMock.disable_net_connect!(allow_localhost: true)

      expect { importer.call(@movie) }.to raise_error(VideoImport::Error, /\Aconnection to 127.0.0.1 failed/)
      expect(connections.size).to eq(1)
    ensure
      WebMock.disable_net_connect!
      hang_up&.kill
      storage&.close
    end

    it "names a server it cannot reach" do
      stub_request(:post, "#{host}/api/v1/auth/token").to_raise(SocketError.new("getaddrinfo: nodename nor servname provided"))

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, "connection to synthwaves.test failed: getaddrinfo: nodename nor servname provided")
    end

    it "names the status when the server replies with something other than JSON" do
      stub_request(:post, "#{host}/api/v1/auth/token").to_return(status: 502, body: "<html>Bad Gateway</html>")

      expect { importer.call(@movie) }
        .to raise_error(VideoImport::Error, "authentication failed (502): the server replied with something other than JSON")
    end
  end
end
