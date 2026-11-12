# Uploads one blob's file to S3-style storage in parts, each sent by the
# client straight to a presigned URL. Storage takes at most 5 GB in one PUT;
# in parts it takes up to 10,000 of up to 5 GiB each. The parts are joined
# into the blob's key, so the blob reads as if it had come up in one PUT.
class MultipartDirectUpload
  class Error < StandardError; end

  PART_NUMBERS = 1..10_000
  PART_SIZE = 100.megabytes

  def self.part_size_for(byte_size) = [PART_SIZE, byte_size.fdiv(PART_NUMBERS.max).ceil].max

  # A blob for the file described, its upload started. Without the upload
  # the blob would be an orphan, so neither outlives the other's failure.
  def self.create!(file, service: nil)
    ActiveStorage::Blob.transaction do
      blob = ActiveStorage::Blob.create_before_direct_upload!(**file)
      start(blob, service: service || blob.service)
    end
  end

  def self.start(blob, service: blob.service) = new(blob, service: service).start

  def self.find(signed_id:, upload_id:)
    new(ActiveStorage::Blob.find_signed!(signed_id), upload_id: upload_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise Error, "invalid signed blob ID"
  end

  attr_reader :upload_id

  delegate :signed_id, to: :blob

  def initialize(blob, upload_id: nil, service: blob.service)
    @blob = blob
    @upload_id = upload_id
    @service = service
  end

  def start
    raise Error, "this server's storage takes no uploads in parts" unless service.respond_to?(:bucket)

    @upload_id = storage.create_multipart_upload(bucket: bucket, key: blob.key,
      content_type: headers["Content-Type"], content_disposition: headers["Content-Disposition"]).upload_id
    self
  end

  def part_size = self.class.part_size_for(blob.byte_size)

  # The URL signs the part's size and checksum, so storage refuses any other bytes.
  def part_url(number, byte_size:, checksum:)
    raise Error, "part number #{number} is outside #{PART_NUMBERS.min} to #{PART_NUMBERS.max}" unless PART_NUMBERS.cover?(number)

    {url: presign(number, byte_size, checksum), headers: {"Content-MD5" => checksum}}
  end

  def complete(parts)
    storage.complete_multipart_upload(bucket: bucket, key: blob.key, upload_id: upload_id,
      multipart_upload: {parts: parts.sort_by { |part| part[:part_number] }})
    refuse_wrong_size
  end

  def abort
    storage.abort_multipart_upload(bucket: bucket, key: blob.key, upload_id: upload_id)
  end

  private

  attr_reader :blob, :service

  def storage = service.client.client

  def bucket = service.bucket.name

  # What a single PUT would send, so the object ends up the same either way.
  def headers
    service.headers_for_direct_upload(blob.key, filename: blob.filename, content_type: blob.content_type, checksum: blob.checksum)
  end

  def presign(number, byte_size, checksum)
    Aws::S3::Presigner.new(client: storage).presigned_url(:upload_part, bucket: bucket, key: blob.key,
      upload_id: upload_id, part_number: number, content_md5: checksum, content_length: byte_size,
      whitelist_headers: ["content-length"], expires_in: ActiveStorage.service_urls_expire_in.to_i)
  end

  # A client that skipped a part would leave a shorter file under the blob.
  def refuse_wrong_size
    stored = storage.head_object(bucket: bucket, key: blob.key).content_length
    return if stored == blob.byte_size

    service.delete(blob.key)
    raise Error, "storage holds #{stored} bytes of the #{blob.byte_size} sent"
  end
end
