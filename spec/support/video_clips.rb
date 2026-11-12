# One-second video clips made with the real ffmpeg, for specs that need the
# real tools to mean anything (encoding, and what the server's conversion job
# does with the result).
require "json"

module VideoClips
  module_function

  def tools? = %w[ffmpeg ffprobe].all? { |tool| system(tool, "-version", out: File::NULL, err: File::NULL) }

  def h264(dir) = make(File.join(dir, "clip.mp4"), "-c:v", "libx264", "-ac", "2")

  # Ten seconds with a keyframe only at the start, so a seek lands between keyframes.
  def h264_one_keyframe(dir) = make(File.join(dir, "long.mp4"), "-c:v", "libx264", "-g", "1000", "-ac", "2", seconds: 10)

  # Not H.264, 5.1 audio, in Matroska: the server re-encodes a file like this.
  def mpeg4_surround(dir) = make(File.join(dir, "clip.mkv"), "-c:v", "mpeg4", "-ac", "6")

  def streams(path)
    data = JSON.parse(IO.popen(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path], &:read))
    video, audio = %w[video audio].map { |type| data["streams"].find { |stream| stream["codec_type"] == type } }
    {video: video&.dig("codec_name"), audio: audio&.dig("codec_name"), channels: audio&.dig("channels"), container: data.dig("format", "format_name")}
  end

  def make(path, *codec_args, seconds: 1)
    system("ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=s=320x240:r=24:d=#{seconds}",
      "-f", "lavfi", "-i", "sine=d=#{seconds}", *codec_args, "-c:a", "aac", "-shortest", path, exception: true)
    path
  end
end
