class YoutubeAlbumImportService
  def self.call(url:, user:, category: "music", playlist_id: nil, new_playlist_name: nil, artist: nil)
    new(url: url, user: user, category: category, playlist_id: playlist_id,
      new_playlist_name: new_playlist_name, artist: artist).call
  end

  def initialize(url:, user:, category:, playlist_id:, new_playlist_name:, artist:)
    @url = url
    @user = user
    @category = category
    @playlist_id = playlist_id
    @new_playlist_name = new_playlist_name
    @artist = artist
  end

  def call
    album = YoutubePlaylistImportService.call(@url, category: @category,
      api_key: @user.youtube_api_key, user: @user, artist: @artist)
    add_tracks_to_playlist(album) if album
    album
  end

  private

  def add_tracks_to_playlist(album)
    playlist = find_or_create_playlist
    playlist&.add_tracks(album.tracks.order(:track_number))
  end

  def find_or_create_playlist
    if @new_playlist_name.present?
      @user.playlists.create!(name: @new_playlist_name)
    elsif @playlist_id.present?
      @user.playlists.find_by(id: @playlist_id)
    end
  end
end
