module VideoImport
  # One stretch of a file uploaded in parts: part +number+, +byte_size+ bytes
  # from +offset+. It reads like a SourceFile, so StorageUpload can send it,
  # and never holds the stretch in memory.
  class FilePart
    CHUNK = 1024 * 1024

    attr_reader :number, :offset, :byte_size

    def self.split(source, part_size)
      (0...source.byte_size).step(part_size).each_with_index.map do |offset, index|
        new(source, number: index + 1, offset: offset, byte_size: [part_size, source.byte_size - offset].min)
      end
    end

    def initialize(source, number:, offset:, byte_size:)
      @source = source
      @number = number
      @offset = offset
      @byte_size = byte_size
    end

    def filename = "part #{number} of #{@source.filename}"

    def checksum
      digest = Digest::MD5.new
      open { |window| while (chunk = window.read(CHUNK)) do digest << chunk end }
      digest.base64digest
    end

    # Yields the stretch as an IO that ends where the part does.
    def open
      @source.open do |file|
        file.seek(offset)
        yield Window.new(file, byte_size)
      end
    end

    # Reads no further than the part's last byte.
    class Window
      def initialize(io, byte_size)
        @io = io
        @left = byte_size
      end

      def read(length = nil, buffer = nil)
        return (length ? nil : +"") if @left.zero?

        @io.read([length || @left, @left].min, buffer).tap { |chunk| @left -= chunk.bytesize if chunk }
      end
    end
  end
end
