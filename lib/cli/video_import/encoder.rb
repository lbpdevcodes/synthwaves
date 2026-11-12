module VideoImport
  # Hands over the file to upload: the source, when the server would keep it
  # as it is, or else a temporary copy converted here the way the server
  # would convert it (see Conversion), so the server has nothing to convert.
  # A file larger than one upload takes (UploadLimit) is encoded in full
  # instead, which makes the video itself smaller.
  class Encoder
    def initialize(out:, ffmpeg: "ffmpeg", ffprobe: "ffprobe", limit: UploadLimit.new)
      @out = out
      @ffmpeg = ffmpeg
      @ffprobe = ffprobe
      @limit = limit
    end

    def prepare(source)
      probe = Probe.of(source.path, ffprobe: @ffprobe)
      settings = Conversion.for(probe)
      return yield(source) if settings.nil? && @limit.fits?(source)

      Dir.mktmpdir("import_video") { |dir| yield fitted(source, probe, settings, dir) }
    end

    # What the server would work out about the prepared file, so it need not
    # download it (ReadyDetails).
    def ready_details(source, &store) = ReadyDetails.new(out: @out, ffmpeg: @ffmpeg, ffprobe: @ffprobe).for(source, &store)

    private

    # Converted as the server would, or else, when that is too large for one
    # upload, encoded in full, which makes the video itself smaller.
    def fitted(source, probe, settings, dir)
      copy = settings ? encode(source, probe, settings, dir) : source
      return copy if @limit.fits?(copy) || settings == Conversion::FULL

      @out.puts("#{@limit.over(copy)}, so the video gets encoded in full")
      encode(source, probe, Conversion::FULL, dir)
    end

    def encode(source, probe, settings, dir)
      copy = File.join(dir, "#{File.basename(source.filename, ".*")}.mp4")
      errors, status = run(["-i", source.path, *settings, copy], meter_for(source, probe))
      raise Error, "encoding #{source.filename} failed (exit #{status.exitstatus}): #{reason(errors)}" unless status.success?

      SourceFile.at(copy)
    end

    # ffmpeg reports progress in microseconds of output written.
    def meter_for(source, probe)
      Meter.new(label: "Encoding #{source.filename}", total: (probe.duration * 1_000_000).to_i, out: @out)
    end

    def run(arguments, meter)
      Open3.popen3(*command(arguments)) do |stdin, stdout, stderr, wait|
        stdin.close
        errors = Thread.new { stderr.read }
        stdout.each_line { |line| track(line, meter) }
        [errors.value, wait.value]
      end
    rescue Errno::ENOENT
      raise VideoImport.missing_tool(@ffmpeg)
    end

    def command(arguments) = [@ffmpeg, "-v", "error", "-nostats", "-progress", "pipe:1", "-y", *arguments]

    # ffmpeg -progress writes key=value lines.
    def track(line, meter)
      key, value = line.strip.split("=", 2)
      meter.update(value.to_i) if key == "out_time_us"
      meter.finish if key == "progress" && value == "end"
    end

    def reason(errors)
      errors.lines.map(&:strip).reject { |line| line.empty? || line == "Conversion failed!" }.last || "no details"
    end
  end
end
