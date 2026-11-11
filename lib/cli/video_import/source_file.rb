module VideoImport
  # A local video file, described the way the direct-upload endpoint expects.
  class SourceFile
    CONTENT_TYPES = {
      ".mp4" => "video/mp4", ".m4v" => "video/mp4", ".mov" => "video/quicktime",
      ".mkv" => "video/x-matroska", ".webm" => "video/webm", ".avi" => "video/x-msvideo"
    }.freeze

    attr_reader :path

    def self.at(path)
      raise Error, "no such file: #{path}" unless File.file?(path)

      new(path)
    end

    def initialize(path)
      @path = path
    end

    def filename = File.basename(path)

    def byte_size = File.size(path)

    def checksum = Digest::MD5.file(path).base64digest

    def content_type = CONTENT_TYPES.fetch(File.extname(path).downcase, "application/octet-stream")

    def open(&) = File.open(path, "rb", &)
  end
end
