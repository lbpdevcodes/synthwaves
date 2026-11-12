# Serves a video's subtitles to its <track> elements, and adds or removes
# them from the video's edit page. The WebVTT is rendered here rather than
# redirected to storage: a <track> only loads from the page's own origin.
class VideoSubtitlesController < ApplicationController
  def show
    render plain: subtitle.vtt, content_type: "text/vtt"
  end

  def create
    if import.save
      redirect_to edit_video_path(video), notice: "Added #{import.subtitle.label}."
    else
      redirect_to edit_video_path(video), alert: import.errors.full_messages.to_sentence
    end
  end

  def destroy
    subtitle.destroy
    redirect_to edit_video_path(video), notice: "Removed #{subtitle.label}."
  end

  private

  def video
    @video ||= Current.user.videos.find(params[:video_id])
  end

  def subtitle
    @subtitle ||= video.subtitles.find(params[:id])
  end

  def import
    @import ||= SubtitleImport.new(video: video, filename: file&.original_filename, data: file&.read,
      label: params.dig(:subtitle, :label))
  end

  def file
    params.dig(:subtitle, :file)
  end
end
