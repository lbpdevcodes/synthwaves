module VideoImport
  # Hands over the file to upload. The server re-encodes any video that is
  # not H.264 (VideoConversionJob's :full path); that is the one expensive
  # conversion, so it happens here instead, into a temporary copy.
  class Encoder
    # VideoConversionJob#convert_to_mp4's arguments, so the server finds
    # nothing left to convert.
    SERVER_SETTINGS = [
      "-c:v", "libx264", "-preset", "medium", "-crf", "23",
      "-ac", "2", "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      "-vf", "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease"
    ].freeze

    def initialize(out:, ffmpeg: "ffmpeg", ffprobe: "ffprobe")
      @out = out
      @ffmpeg = ffmpeg
      @ffprobe = ffprobe
    end

    def prepare(source)
      probe = Probe.of(source.path, ffprobe: @ffprobe)
      return yield(source) if probe.h264?

      Dir.mktmpdir("import_video") { |dir| yield encode(source, probe, dir) }
    end

    private

    def encode(source, probe, dir)
      copy = File.join(dir, "#{File.basename(source.filename, ".*")}.mp4")
      errors, status = run(source.path, copy, meter_for(source, probe))
      raise Error, "encoding #{source.filename} failed (exit #{status.exitstatus}): #{reason(errors)}" unless status.success?

      SourceFile.at(copy)
    end

    # ffmpeg reports progress in microseconds of output written.
    def meter_for(source, probe)
      Meter.new(label: "Encoding #{source.filename}", total: (probe.duration * 1_000_000).to_i, out: @out)
    end

    def run(input, output, meter)
      Open3.popen3(*command(input, output)) do |stdin, stdout, stderr, wait|
        stdin.close
        errors = Thread.new { stderr.read }
        stdout.each_line { |line| track(line, meter) }
        [errors.value, wait.value]
      end
    rescue Errno::ENOENT
      raise VideoImport.missing_tool(@ffmpeg)
    end

    def command(input, output)
      [@ffmpeg, "-v", "error", "-nostats", "-progress", "pipe:1", "-y", "-i", input, *SERVER_SETTINGS, output]
    end

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
