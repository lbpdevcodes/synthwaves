module VideoImport
  # The text subtitle tracks inside a video file (an MKV's subrip, say),
  # written out as .srt files named the way the server reads a subtitle
  # file's name: eng.srt, SDH.eng.srt. Image subtitles (Blu-ray PGS) cannot
  # become text, so they are left out.
  class EmbeddedSubtitles
    TEXT_CODECS = %w[subrip srt ass ssa mov_text webvtt text].freeze
    CAPTIONS = /\b(SDH|HI|CC)\b/i

    def initialize(ffmpeg: "ffmpeg", ffprobe: "ffprobe")
      @ffmpeg = ffmpeg
      @ffprobe = ffprobe
    end

    # The name each text track's file gets, in track order.
    def names(path) = named(text_tracks(path))

    # Writes every text track to dir in one pass and returns the files.
    def extract(path, dir)
      tracks = text_tracks(path)
      files = named(tracks).map { |name| File.join(dir, "#{name}.srt") }
      run(path, tracks.zip(files).flat_map { |track, srt| ["-map", "0:#{track["index"]}", "-c:s", "srt", srt] }) unless tracks.empty?
      files
    end

    private

    def text_tracks(path) = Probe.of(path, ffprobe: @ffprobe).subtitle_streams.select { |track| TEXT_CODECS.include?(track["codec_name"]) }

    def named(tracks) = numbered(tracks.map { |track| name_for(track) })

    def name_for(track)
      language = track.dig("tags", "language").to_s
      name = (language.empty? || language == "und") ? "Subtitles" : language
      captions?(track) ? "SDH.#{name}" : name
    end

    def captions?(track) = track.dig("disposition", "hearing_impaired") == 1 || track.dig("tags", "title").to_s.match?(CAPTIONS)

    # eng, 2_eng, 3_eng: the server reads past the number and labels a
    # repeat the way it labels any repeat, "English 2".
    def numbered(names) = names.each_with_index.map { |name, at| (seen = names.take(at).count(name)).zero? ? name : "#{seen + 1}_#{name}" }

    def run(path, outputs)
      _out, errors, status = Open3.capture3(@ffmpeg, "-v", "error", "-y", "-i", path, *outputs)
      raise Error, "could not read the subtitles inside #{File.basename(path)}: #{errors.lines.last.to_s.strip}" unless status.success?
    rescue Errno::ENOENT
      raise VideoImport.missing_tool(@ffmpeg)
    end
  end
end
