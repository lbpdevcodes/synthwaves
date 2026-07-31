class YoutubeImportJob < ApplicationJob
  queue_as :imports

  def perform(url, category: "music", download: false, user_id: nil, playlist_id: nil, new_playlist_name: nil, artist_id: nil)
    user = User.find(user_id)
    artist = artist_id ? user.artists.find_by(id: artist_id) : nil
    album = YoutubeAlbumImportService.call(url: url, user: user, category: category,
      playlist_id: playlist_id, new_playlist_name: new_playlist_name, artist: artist)

    enqueue_downloads(album, user_id) if download && album && user_id
  end

  private

  def enqueue_downloads(album, user_id)
    album.tracks.where.not(youtube_video_id: [nil, ""]).find_each do |track|
      next if track.audio_file.attached?

      video_url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
      MediaDownloadJob.perform_later(track.id, video_url, user_id: user_id)
    end
  end
end
