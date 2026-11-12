module VideoImport
  # What the server's VideoConversionJob would work out about a file it keeps
  # as it is: the details it reads (Probe#details) and the thumbnail it makes,
  # with the job's exact command. Sent with the upload, they let the server
  # file the video ready without downloading it. A file the server would
  # still convert gets nothing, and neither does one this cannot thumbnail:
  # the server then makes both itself, as it always has.
  class ReadyDetails
    def initialize(out:, ffmpeg: "ffmpeg", ffprobe: "ffprobe")
      @out = out
      @ffmpeg = ffmpeg
      @ffprobe = ffprobe
    end

    # Yields the thumbnail to be stored and expects its signed blob id back.
    def for(source)
      probe = Probe.of(source.path, ffprobe: @ffprobe)
      return {} if Conversion.for(probe)

      Dir.mktmpdir("import_video") { |dir| {details: probe.details, thumbnail_signed_blob_id: yield(thumbnail(source, probe, dir))} }
    rescue Error => e
      @out.puts("The server will make the thumbnail: #{e.message}")
      {}
    end

    private

    # VideoConversionJob#generate_thumbnail: one frame a tenth of the way in.
    def thumbnail(source, probe, dir)
      jpeg = File.join(dir, "thumbnail.jpg")
      seek = probe.details[:duration] ? (probe.details[:duration] * 0.1).round(2) : 1
      run(["-y", "-ss", seek.to_s, "-i", source.path, "-vframes", "1", "-vf", "scale=640:-1", jpeg])
      SourceFile.at(jpeg)
    end

    def run(arguments)
      _out, errors, status = Open3.capture3(@ffmpeg, "-v", "error", *arguments)
      raise Error, errors.lines.last.to_s.strip unless status.success?
    rescue Errno::ENOENT
      raise VideoImport.missing_tool(@ffmpeg)
    end
  end
end
