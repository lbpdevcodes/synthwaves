module VideoImport
  # Prints "\rLABEL:  NN%" each time the percentage moves, and a newline at 100%.
  class Meter
    # This meter, counting from +offset+: one part of a file uploaded in parts.
    Offset = Data.define(:meter, :offset) do
      def update(done) = meter.update(offset + done)
    end

    def self.uploading(source, out) = new(label: "Uploading #{source.filename}", total: source.byte_size, out: out)

    def initialize(label:, total:, out:)
      @label = label
      @total = [total, 1].max
      @out = out
    end

    def update(done)
      percent = [done * 100 / @total, 100].min.to_i
      return if percent == @shown

      @shown = percent
      @out.print("\r#{@label}: #{percent.to_s.rjust(3)}%")
      @out.puts if percent == 100
    end

    def finish = update(@total)

    def from(offset) = Offset.new(meter: self, offset: offset)
  end
end
