module VideoImport
  # What ffprobe reports about a video file, read the way the server's
  # VideoMetadataExtractor reads it: the first video and audio streams.
  class Probe
    # VideoConversionJob::MP4_CONTAINERS, matched against ffprobe's format name.
    MP4_CONTAINERS = %w[mov,mp4,m4a,3gp,3g2,mj2 mp4 m4v].freeze

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

    def aac? = audio.fetch("codec_name", "").include?("aac")

    def surround? = audio.fetch("channels", 0) > 2

    def mp4? = MP4_CONTAINERS.any? { |name| container.include?(name) }

    def duration = @data.dig("format", "duration").to_f

    private

    def video_codec = stream("video")["codec_name"]

    def audio = stream("audio")

    def container = @data.dig("format", "format_name").to_s

    def stream(type) = @data.fetch("streams", []).find { |stream| stream["codec_type"] == type } || {}
  end
end
