module VideoImport
  # The video files under a folder, sorted by path. A download still in
  # progress (Movie.mp4.part) is listed under the name it will have. Hidden
  # files are left out, and links to folders are not followed.
  #
  # A folder it may not read is left out too, and passed to the block with
  # the reason: macOS keeps ~/Movies/TV, the TV app's library, from a
  # terminal that has not been given access to it.
  module FolderScan
    EXTENSIONS = %w[.mkv .mp4 .m4v .mov .avi .webm].freeze

    def self.videos(folder, &unreadable)
      files(folder, &unreadable)
        .map { |path| path.delete_suffix(".part") }
        .select { |path| EXTENSIONS.include?(File.extname(path).downcase) }
        .uniq.sort_by(&:downcase)
    end

    def self.files(dir, &unreadable)
      visible(dir).flat_map { |path| File.lstat(path).directory? ? files(path, &unreadable) : [path] }
    rescue Errno::EPERM, Errno::EACCES => e
      unreadable&.call(dir, SystemCallError.new(nil, e.errno).message)
      []
    end

    def self.visible(dir) = Dir.children(dir).reject { |name| name.start_with?(".") }.map { |name| File.join(dir, name) }

    private_class_method :files, :visible
  end
end
