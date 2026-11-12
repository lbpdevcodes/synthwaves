# Files one subtitle file on a video the caller owns. bin/import_video sends
# each .srt beside the movie here after filing the video. The file arrives
# base64-encoded in JSON, because its bytes may not be UTF-8.
class API::Import::SubtitlesController < API::Import::BaseController
  def create
    if import.save
      render json: summary(import.subtitle), status: :created
    else
      render json: {error: import.errors.full_messages.to_sentence}, status: :unprocessable_content
    end
  end

  private

  def import
    @import ||= SubtitleImport.new(video: current_user.videos.find(params[:video_id]),
      filename: params[:filename], data: params[:content_base64].to_s.unpack1("m"), label: params[:label])
  end

  def summary(subtitle)
    {id: subtitle.id, label: subtitle.label, language: subtitle.language, kind: subtitle.kind}
  end
end
