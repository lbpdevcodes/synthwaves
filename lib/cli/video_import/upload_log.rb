module VideoImport
  # The videos a folder import has filed, kept in the folder's
  # synthwaves-uploaded.log so a rerun never uploads a title twice. One line
  # per video: "Shrek<TAB>video 1320<TAB>2026-11-11 22:40:00", the format
  # tmp/upload_movies.sh wrote before this existed.
  class UploadLog
    FILE = "synthwaves-uploaded.log".freeze

    def self.in(folder) = new(File.join(folder, FILE))

    def initialize(path)
      @path = path
    end

    # The id of the video filed under this title, or nil.
    def filed(title)
      entry = entries.find { |fields| fields.first == title }
      entry && entry[1].delete_prefix("video ").to_i
    end

    def record(title, video_id)
      File.open(@path, "a") { |file| file.puts([title, "video #{video_id}", Time.now.strftime("%F %T")].join("\t")) }
    end

    private

    def entries = File.file?(@path) ? File.readlines(@path, chomp: true).map { |line| line.split("\t") } : []
  end
end
