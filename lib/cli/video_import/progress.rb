module VideoImport
  # Wraps the file being uploaded and prints how much of it has been read.
  # Net::HTTP pulls the request body through #read, so bytes read are bytes sent.
  class Progress
    def initialize(io, total:, label:, out:)
      @io = io
      @total = [total, 1].max
      @label = label
      @out = out
      @sent = 0
    end

    def read(length = nil, buffer = nil)
      @io.read(length, buffer).tap { |chunk| advance(chunk.bytesize) if chunk }
    end

    private

    def advance(bytes)
      @sent += bytes
      @out.print("\r#{@label}: #{(@sent * 100 / @total).to_s.rjust(3)}%")
      @out.puts if @sent >= @total
    end
  end
end
