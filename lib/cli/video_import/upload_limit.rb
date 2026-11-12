module VideoImport
  # The largest file storage takes in one PUT. Linode's S3-style storage
  # refuses more with EntityTooLarge, so a larger file goes up in parts
  # (MultipartUpload).
  class UploadLimit
    BYTES = 5_000_000_000

    def initialize(bytes = BYTES)
      @bytes = bytes
    end

    def fits?(source) = source.byte_size <= @bytes
  end
end
