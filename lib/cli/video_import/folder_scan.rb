module VideoImport
  # The video files under a folder, sorted by path. A download still in
  # progress (Movie.mp4.part) is listed under the name it will have.
  module FolderScan
    EXTENSIONS = %w[.mkv .mp4 .m4v .mov .avi .webm].freeze

    def self.videos(folder)
      Dir.glob("**/*", base: folder)
        .map { |relative| relative.delete_suffix(".part") }
        .select { |relative| EXTENSIONS.include?(File.extname(relative).downcase) }
        .uniq.sort_by(&:downcase).map { |relative| File.join(folder, relative) }
    end
  end
end
