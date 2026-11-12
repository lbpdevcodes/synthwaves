module VideoImport
  # What ffprobe reports about a video file.
  class Probe
    def self.of(path, ffprobe:)
      output, errors, status = Open3.capture3(ffprobe, "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path)
      raise Error, "could not read #{path} as a video: #{reason(errors, path)}" unless status.success?

      new(JSON.parse(output))
    rescue Errno::ENOENT
      raise VideoImport.missing_tool(ffprobe)
    end

    # ffprobe's last line names the problem, prefixed with the path.
    def self.reason(errors, path) = errors.lines.last.to_s.strip.delete_prefix("#{path}: ")

    def initialize(data)
      @data = data
    end

    def h264? = video_codec == "h264"

    def duration = @data.dig("format", "duration").to_f

    def video_codec = @data.fetch("streams", []).find { |stream| stream["codec_type"] == "video" }&.dig("codec_name")
  end
end
