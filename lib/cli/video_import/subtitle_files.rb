module VideoImport
  # The subtitle files that came with a video: those in a Subs folder beside
  # it, or in Subs/<video name>/, then those beside it named after it. A file
  # found twice (Movie.srt and Subs/English.srt, byte for byte) is kept once,
  # under its Subs name, which says more about it.
  class SubtitleFiles
    EXTENSIONS = %w[.srt .vtt].freeze

    def self.beside(video_path) = new(video_path).paths

    def initialize(video_path)
      @video_path = video_path
    end

    def paths
      (in_subs + named_after_video).uniq { |path| Digest::SHA256.file(path).digest }
    end

    private

    def folder = File.dirname(@video_path)

    def video_name = File.basename(@video_path, ".*")

    def in_subs
      subs = File.join(folder, "Subs")
      subtitles_in(subs) + subtitles_in(File.join(subs, video_name))
    end

    def named_after_video
      subtitles_in(folder).select { |path| File.basename(path).downcase.start_with?(video_name.downcase) }
    end

    # Dir.children, not Dir.glob: release folder names carry [brackets].
    def subtitles_in(directory)
      return [] unless File.directory?(directory)

      Dir.children(directory).sort
        .select { |name| EXTENSIONS.include?(File.extname(name).downcase) }
        .map { |name| File.join(directory, name) }
    end
  end
end
