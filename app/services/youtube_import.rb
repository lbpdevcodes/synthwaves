# What importing one YouTube playlist produced: the playlist's title and its
# tracks in playlist order, plus the library playlist they were added to.
YoutubeImport = Data.define(:title, :tracks, :playlist) do
  def initialize(title:, tracks:, playlist: nil)
    super
  end

  # The one album every track landed in -- a podcast or a full-album rip -- or
  # nil when the tracks went to their own artists' albums.
  def album
    albums = tracks.map(&:album).uniq
    albums.first if albums.one?
  end

  # The import reply the REST API and the MCP tool both send. missing_audio
  # is the work list bin/import_audio pushes audio for.
  def summary
    {
      album_id: album&.id, playlist_id: playlist&.id, title: title,
      track_count: tracks.size, track_ids: tracks.map(&:id),
      tracks_missing_audio: missing_audio.size, missing_audio: missing_audio
    }
  end

  private

  def missing_audio
    tracks.reject { |track| track.audio_file.attached? }
      .map { |track| {id: track.id, title: track.title, youtube_video_id: track.youtube_video_id} }
  end
end
