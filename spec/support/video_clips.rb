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

  # H.264 with stereo sound that is not AAC: the server converts the sound.
  def h264_ac3(dir) = make(File.join(dir, "ac3.mkv"), "-c:v", "libx264", "-c:a", "ac3", "-ac", "2")

  # H.264 with 5.1 AAC in an MP4: the server converts the sound to stereo.
  def h264_surround(dir) = make(File.join(dir, "surround.mp4"), "-c:v", "libx264", "-ac", "6")

  # H.264 and stereo AAC in Matroska: the server repackages it as MP4.
  def h264_matroska(dir) = make(File.join(dir, "stereo.mkv"), "-c:v", "libx264", "-ac", "2")

  def streams(path)
    data = JSON.parse(IO.popen(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path], &:read))
    video, audio = %w[video audio].map { |type| data["streams"].find { |stream| stream["codec_type"] == type } }
    {video: video&.dig("codec_name"), audio: audio&.dig("codec_name"), channels: audio&.dig("channels"), container: data.dig("format", "format_name")}
  end

  # A hash of one stream's packets (:video or :audio). It changes when the
  # stream is re-encoded, and not when the stream is copied into another file.
  def stream_hash(path, type) = IO.popen(["ffmpeg", "-v", "error", "-i", path, "-map", "0:#{type.to_s[0]}:0", "-c", "copy", "-f", "md5", "-"], &:read)

  def make(path, *codec_args, seconds: 1)
    system("ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=s=320x240:r=24:d=#{seconds}",
      "-f", "lavfi", "-i", "sine=d=#{seconds}", "-c:a", "aac", *codec_args, "-shortest", path, exception: true)
    path
  end
end
