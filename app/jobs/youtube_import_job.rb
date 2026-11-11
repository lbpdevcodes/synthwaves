class YoutubeImportJob < ApplicationJob
  queue_as :imports

  def perform(url, category: "music", download: false, user_id: nil, playlist_id: nil, new_playlist_name: nil)
    user = User.find(user_id)
    import = YoutubeAlbumImportService.call(url: url, user: user, category: category,
      playlist_id: playlist_id, new_playlist_name: new_playlist_name)

    enqueue_downloads(import.tracks, user_id) if download && import && user_id
  end

  private

  def enqueue_downloads(tracks, user_id)
    tracks.each do |track|
      next if track.youtube_video_id.blank? || track.audio_file.attached?

      video_url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
      MediaDownloadJob.perform_later(track.id, video_url, user_id: user_id)
    end
  end
end
