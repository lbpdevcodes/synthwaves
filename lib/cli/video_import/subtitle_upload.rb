module VideoImport
  # Adds subtitle files to a video the server has filed. One refused file
  # does not stop the rest: the video is already up, and a subtitle can be
  # added again from the video's edit page.
  class SubtitleUpload
    def initialize(api:, out:)
      @api = api
      @out = out
    end

    # Returns what failed, one line per file, with the reason.
    def call(video_id, paths)
      paths.filter_map { |path| failure_adding(video_id, path) }
    end

    private

    def failure_adding(video_id, path)
      @out.puts "Added subtitles: #{@api.add_subtitle(video_id, path).fetch("label")}"
      nil
    rescue Error => e
      "#{File.basename(path)}: #{e.message}"
    end
  end
end
