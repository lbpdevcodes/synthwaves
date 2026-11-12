# What VideoConversionJob does to an uploaded video, chosen from what ffprobe
# says about it (VideoMetadataExtractor's fields): :none when browsers play it
# as it is, else the cheapest conversion that makes it playable. The import
# endpoint asks it too, to file a video ready (PreparedVideo), and
# bin/import_video makes the same choice locally (VideoImport::Conversion).
module VideoConversionStrategy
  MP4_CONTAINERS = %w[mov,mp4,m4a,3gp,3g2,mj2 mp4 m4v].freeze

  def self.for(metadata)
    return :full unless metadata[:video_codec]

    h264 = metadata[:video_codec] == "h264"
    aac = metadata[:audio_codec]&.match?(/aac/)
    mp4_container = MP4_CONTAINERS.any? { |c| metadata[:container]&.include?(c) }
    normalize_audio = needs_audio_normalization?(metadata)

    if h264 && aac && mp4_container && !normalize_audio
      :none
    elsif h264 && aac && !normalize_audio
      :remux
    elsif h264
      :transcode_audio
    else
      :full
    end
  end

  def self.needs_audio_normalization?(metadata)
    return false unless metadata[:audio_channels]

    metadata[:audio_channels] > 2
  end
end
