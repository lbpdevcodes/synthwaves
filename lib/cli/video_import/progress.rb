module VideoImport
  # Wraps the file being uploaded and moves a Meter as it is read.
  # Net::HTTP pulls the request body through #read, so bytes read are bytes sent.
  class Progress
    def initialize(io, meter)
      @io = io
      @meter = meter
      @sent = 0
    end

    def read(length = nil, buffer = nil)
      @io.read(length, buffer).tap { |chunk| advance(chunk.bytesize) if chunk }
    end

    private

    def advance(bytes)
      @sent += bytes
      @meter.update(@sent)
    end
  end
end
