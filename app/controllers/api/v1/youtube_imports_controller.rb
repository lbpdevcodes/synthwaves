class API::V1::YoutubeImportsController < API::V1::BaseController
  def create
    album = YoutubeAlbumImportService.call(
      url: params[:url],
      user: current_user,
      category: params[:category].presence || "music",
      playlist_id: params[:playlist_id],
      new_playlist_name: params[:new_playlist_name]
    )

    return render_error("No videos found in that playlist") if album.nil?

    render json: {
      album_id: album.id,
      title: album.title,
      track_count: album.tracks.count,
      tracks_missing_audio: album.tracks.where.missing(:audio_file_attachment).count
    }, status: :created
  rescue YoutubePlaylistImportService::Error, YoutubeAPIService::Error, MediaDownloadService::Error => e
    render_error(e.message)
  end
end
