# A video bin/import_video prepared for the server: converted the way
# VideoConversionJob would convert it, and sent with the thumbnail and the
# details the job would have made and read from it. When the details say the
# job would keep the file as it is, the video is filed ready with them, and
# the job never runs (Video#convert_video), so the server never downloads it.
# Anything less goes through the job as before.
class PreparedVideo
  DETAILS = %i[duration width height video_codec audio_codec audio_channels bitrate container].freeze
  STORED = DETAILS - [:container]

  def initialize(video, details:, thumbnail:)
    @video = video
    @details = details.to_h.symbolize_keys.slice(*DETAILS)
    @thumbnail = thumbnail
  end

  def apply
    return unless ready_as_is?

    @video.assign_attributes(@details.slice(*STORED).merge(status: "ready"))
    @video.thumbnail.attach(@thumbnail)
  end

  private

  def ready_as_is? = @thumbnail.present? && VideoConversionStrategy.for(metadata) == :none

  # JSON numbers arrive as numbers; a form post sends strings.
  def metadata = @details.merge(audio_channels: @details[:audio_channels]&.to_i)
end
