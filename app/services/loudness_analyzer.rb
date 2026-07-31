require "open3"

# Measures a file's loudness with ffmpeg's loudnorm filter (analysis pass
# only) and computes the playback gain needed to reach streaming-standard
# loudness without clipping. Analysis only — the audio is never modified.
class LoudnessAnalyzer
  TARGET_LUFS = -14.0
  TRUE_PEAK_CEILING_DB = -1.0

  Error = Class.new(StandardError)

  def self.call(file_path)
    new(file_path).call
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    {
      integrated_lufs: integrated_lufs,
      true_peak_db: true_peak_db,
      gain_db: gain_db
    }
  end

  private

  attr_reader :file_path

  def integrated_lufs = measurement.fetch("input_i")
  def true_peak_db = measurement.fetch("input_tp")

  def gain_db
    [TARGET_LUFS - integrated_lufs, TRUE_PEAK_CEILING_DB - true_peak_db].min.round(2)
  end

  def measurement
    @measurement ||= parse(loudnorm_output)
  end

  def loudnorm_output
    _stdout, stderr, status = Open3.capture3(
      "ffmpeg", "-hide_banner", "-nostats", "-i", file_path,
      "-af", "loudnorm=I=#{TARGET_LUFS}:TP=#{TRUE_PEAK_CEILING_DB}:print_format=json",
      "-f", "null", "-"
    )
    raise Error, "ffmpeg loudnorm failed: #{stderr.to_s.last(500)}" unless status.success?

    stderr
  end

  # loudnorm prints its measurements as the last JSON object on stderr
  def parse(output)
    json = output.to_s.scan(/\{[^{}]*\}/m).last
    raise Error, "no loudnorm measurements in ffmpeg output" unless json

    values = JSON.parse(json)
    {
      "input_i" => Float(values.fetch("input_i")),
      "input_tp" => Float(values.fetch("input_tp"))
    }
  rescue JSON::ParserError, KeyError, ArgumentError => e
    raise Error, "unparseable loudnorm output: #{e.message}"
  end
end
