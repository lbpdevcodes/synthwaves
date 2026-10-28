class StreamRecorderService
  Result = Data.define(:output_path, :duration, :file_size, :error)

  def self.call(stream_url:, duration_seconds:, output_path:, cancelled: -> { false })
    new(stream_url:, duration_seconds:, output_path:, cancelled:).call
  end

  def initialize(stream_url:, duration_seconds:, output_path:, cancelled: -> { false })
    @stream_url = stream_url
    @duration_seconds = duration_seconds
    @output_path = output_path
    @cancelled = cancelled
  end

  def call
    case CancellableCommand.run(*ffmpeg_command, cancelled: @cancelled)
    when :succeeded
      Result.new(output_path: @output_path, duration: probe_duration(@output_path), file_size: File.size(@output_path), error: nil)
    when :cancelled
      failure("recording cancelled")
    else
      failure("ffmpeg recording failed")
    end
  end

  private

  def ffmpeg_command
    [
      "ffmpeg", "-y",
      "-i", @stream_url,
      "-t", @duration_seconds.to_s,
      "-c", "copy",
      "-movflags", "+faststart",
      @output_path
    ]
  end

  def failure(error)
    Result.new(output_path: @output_path, duration: nil, file_size: nil, error:)
  end

  def probe_duration(path)
    output = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 #{Shellwords.escape(path)} 2>/dev/null`.strip
    output.present? ? output.to_f : nil
  end
end
