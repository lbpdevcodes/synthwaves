class API::Subsonic::VideoController < API::Subsonic::BaseController
  def get_videos
    videos = current_user.videos.ready.includes(:folder, taggings: :tag)
    videos = videos.where(folder_id: params[:folderId]) if params[:folderId].present?
    videos = videos.search(params[:query]) if params[:query].present?

    render_subsonic(videos: {video: videos.map { |v| video_to_entry(v) }})
  end

  def get_video
    video = current_user.videos.find(params[:id])
    render_subsonic(video: Subsonic::VideoSerializer.to_detail(video))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def get_video_subtitle
    subtitle = current_user.videos.find(params[:videoId]).subtitles.find(params[:id])
    render plain: subtitle.vtt, content_type: "text/vtt"
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Subtitle not found")
  end

  def stream
    video = current_user.videos.ready.find(params[:id])
    if video.file.attached?
      redirect_to rails_blob_url(video.file), allow_other_host: true
    else
      render_subsonic_error(70, "Video not found")
    end
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def get_thumbnail
    video = current_user.videos.find(params[:id])
    video.thumbnail.attached? ? redirect_to_image(video.thumbnail) : head(:not_found)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def save_playback_position
    video = current_user.videos.find(params[:id])
    position = current_user.video_playback_positions.find_or_initialize_by(video: video)
    position.position = params[:position].to_f
    position.save!

    render_subsonic
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def get_playback_position
    video = current_user.videos.find(params[:id])
    position = current_user.video_playback_positions.find_by(video: video)

    render_subsonic(playbackPosition: {id: video.id.to_s, position: position&.position || 0})
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end
end
