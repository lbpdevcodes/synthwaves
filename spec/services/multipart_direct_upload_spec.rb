require "rails_helper"
require "active_storage/service/s3_service"

RSpec.describe MultipartDirectUpload do
  let(:service) do
    ActiveStorage::Service::S3Service.new(bucket: "videos", region: "us-east-1",
      access_key_id: "id", secret_access_key: "secret", stub_responses: true)
  end
  let(:storage) { service.client.client }
  let(:blob) do
    ActiveStorage::Blob.create_before_direct_upload!(filename: "City of God.mp4", byte_size: 8_000_000_000,
      checksum: Digest::MD5.base64digest("film"), content_type: "video/mp4")
  end

  before { storage.stub_responses(:create_multipart_upload, upload_id: "upload-1") }

  def requests(operation) = storage.api_requests.select { |request| request[:operation_name] == operation }.map { |request| request[:params] }

  describe ".part_size_for" do
    it "sends a film in 100 MiB parts" do
      expect(described_class.part_size_for(8_000_000_000)).to eq(100.megabytes)
    end

    it "makes the parts larger when 100 MiB ones would need more than 10,000" do
      expect(described_class.part_size_for(2_000_000_000_000)).to eq(200_000_000)
    end
  end

  describe ".create!" do
    let(:file) { {filename: "City of God.mp4", byte_size: 8_000_000_000, checksum: Digest::MD5.base64digest("film"), content_type: "video/mp4"} }

    it "makes the blob and starts its upload at the blob's key" do
      upload = described_class.create!(file, service: service)

      created = ActiveStorage::Blob.find_signed!(upload.signed_id)
      expect(created).to have_attributes(filename: "City of God.mp4", byte_size: 8_000_000_000)
      expect(requests(:create_multipart_upload)).to contain_exactly(hash_including(key: created.key))
      expect(upload).to have_attributes(upload_id: "upload-1", part_size: 100.megabytes)
    end

    it "keeps no blob when storage takes no uploads in parts" do
      expect { described_class.create!(file) }.to raise_error(MultipartDirectUpload::Error)
      expect(ActiveStorage::Blob.count).to eq(0)
    end
  end

  describe ".find" do
    it "picks up an upload by its blob's signed id" do
      upload = described_class.find(signed_id: blob.signed_id, upload_id: "upload-1")

      expect(upload).to have_attributes(signed_id: blob.signed_id, upload_id: "upload-1")
    end

    it "refuses a signed id this server did not sign" do
      expect { described_class.find(signed_id: "forged", upload_id: "upload-1") }
        .to raise_error(MultipartDirectUpload::Error, "invalid signed blob ID")
    end
  end

  describe ".start" do
    it "starts an upload at the blob's key with the type and disposition a single PUT would set" do
      described_class.start(blob, service: service)

      expect(requests(:create_multipart_upload)).to contain_exactly(hash_including(
        bucket: "videos", key: blob.key, content_type: "video/mp4",
        content_disposition: a_string_starting_with("inline; filename=\"City of God.mp4\"")
      ))
    end

    it "names storage's reason when it will not start the upload" do
      storage.stub_responses(:create_multipart_upload, "AccessDenied")

      expect { described_class.start(blob, service: service) }.to raise_error(MultipartDirectUpload::Error, /\Astorage refused it \(AccessDenied\)/)
    end

    it "refuses storage that takes no uploads in parts, like the disk" do
      expect { described_class.start(blob) }
        .to raise_error(MultipartDirectUpload::Error, "this server's storage takes no uploads in parts")
    end
  end

  describe "#part_url" do
    let(:upload) { described_class.new(blob, upload_id: "upload-1", service: service) }
    let(:checksum) { Digest::MD5.base64digest("part two") }

    it "presigns one part's PUT, signing its size and checksum so storage checks both" do
      part = upload.part_url(2, byte_size: 104_857_600, checksum: checksum)

      query = Rack::Utils.parse_query(URI(part[:url]).query)
      expect(query).to include("partNumber" => "2", "uploadId" => "upload-1", "X-Amz-SignedHeaders" => "content-length;content-md5;host")
      expect(part[:headers]).to eq("Content-MD5" => checksum)
    end

    it "refuses a part number storage would not take" do
      expect { upload.part_url(10_001, byte_size: 1, checksum: checksum) }
        .to raise_error(MultipartDirectUpload::Error, "part number 10001 is outside 1 to 10000")
    end
  end

  describe "#complete" do
    let(:upload) { described_class.new(blob, upload_id: "upload-1", service: service) }
    let(:parts) { [{part_number: 2, etag: "\"b\""}, {part_number: 1, etag: "\"a\""}] }

    it "joins the parts in order" do
      storage.stub_responses(:head_object, content_length: blob.byte_size)

      upload.complete(parts)

      expect(requests(:complete_multipart_upload)).to contain_exactly(hash_including(
        bucket: "videos", key: blob.key, upload_id: "upload-1",
        multipart_upload: {parts: [{part_number: 1, etag: "\"a\""}, {part_number: 2, etag: "\"b\""}]}
      ))
    end

    it "deletes and refuses an object that came out a different size than the blob says" do
      storage.stub_responses(:head_object, content_length: 104_857_600)

      expect { upload.complete(parts) }
        .to raise_error(MultipartDirectUpload::Error, "storage holds 104857600 bytes of the 8000000000 sent")
      expect(requests(:delete_object)).to contain_exactly(hash_including(bucket: "videos", key: blob.key))
    end

    it "names storage's reason when it will not join the parts" do
      storage.stub_responses(:complete_multipart_upload, "InvalidPart")

      expect { upload.complete(parts) }.to raise_error(MultipartDirectUpload::Error, /\Astorage refused it \(InvalidPart\)/)
    end
  end

  describe "#abort" do
    it "throws away the parts storage holds so far" do
      described_class.new(blob, upload_id: "upload-1", service: service).abort

      expect(requests(:abort_multipart_upload)).to contain_exactly(hash_including(bucket: "videos", key: blob.key, upload_id: "upload-1"))
    end

    it "counts an upload storage no longer has as thrown away" do
      storage.stub_responses(:abort_multipart_upload, "NoSuchUpload")

      expect { described_class.new(blob, upload_id: "upload-1", service: service).abort }.not_to raise_error
    end
  end
end
