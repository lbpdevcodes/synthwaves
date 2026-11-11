class YoutubeAlbumImportService
  def self.call(url:, user:, category: "music", playlist_id: nil, new_playlist_name: nil)
    new(url: url, user: user, category: category, playlist_id: playlist_id,
      new_playlist_name: new_playlist_name).call
  end

  def initialize(url:, user:, category:, playlist_id:, new_playlist_name:)
    @url = url
    @user = user
    @category = category
    @playlist_id = playlist_id
    @new_playlist_name = new_playlist_name
  end

  # Returns the YoutubeImport, with the playlist the tracks were added to, or
  # nil when the YouTube playlist holds no videos.
  def call
    import = YoutubePlaylistImportService.call(@url, category: @category,
      api_key: @user.youtube_api_key, user: @user)
    import && add_to_playlist(import)
  end

  private

  def add_to_playlist(import)
    playlist = find_or_create_playlist(import)
    playlist&.add_tracks(import.tracks)
    import.with(playlist: playlist)
  end

  # A music playlist's grouping lives on as a library playlist of the same
  # name; a podcast's lives in its album. Found by name, so re-running an
  # import (bin/import_audio resumes that way) never adds a second playlist.
  def find_or_create_playlist(import)
    return @user.playlists.find_by(id: @playlist_id) if @new_playlist_name.blank? && @playlist_id.present?

    name = @new_playlist_name.presence || (import.title if @category == "music")
    @user.playlists.find_or_create_by!(name: name) if name
  end
end
