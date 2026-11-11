class API::V1::YoutubeImportsController < API::V1::BaseController
  def create
    import = YoutubeAlbumImportService.call(
      url: params[:url],
      user: current_user,
      category: params[:category].presence || "music",
      playlist_id: params[:playlist_id],
      new_playlist_name: params[:new_playlist_name]
    )

    return render_error("No videos found in that playlist") if import.nil?

    render json: import.summary, status: :created
  rescue YoutubePlaylistImportService::Error, YoutubeAPIService::Error, MediaDownloadService::Error => e
    render_error(e.message)
  end
end
