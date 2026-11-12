module VideoImport
  # The largest file storage takes in one upload. Linode's S3-style storage
  # refuses more with EntityTooLarge, and nothing here uploads in parts.
  class UploadLimit
    BYTES = 5_000_000_000

    def initialize(bytes = BYTES)
      @bytes = bytes
    end

    def fits?(source) = source.byte_size <= @bytes

    def over(source) = "#{source.filename} is #{gigabytes(source.byte_size)}, over the #{gigabytes(@bytes)} storage takes in one upload"

    private

    def gigabytes(bytes) = format("%.1f GB", bytes / 1e9)
  end
end
