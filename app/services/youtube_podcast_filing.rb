# Files a YouTube podcast playlist the way a show is organised: the channel is
# the artist and the playlist is the album, every episode in it. This is how
# every playlist import used to be filed.
class YoutubePodcastFiling
  include YoutubePlaylistAdoption

  def initialize(user:, url:, playlist_info:)
    @user = user
    @url = url
    @playlist_info = playlist_info
  end

  def file(item)
    enriched = YoutubeMetadataEnricher.call(
      title: item[:title], channel_name: playlist_info[:channel_name], playlist_title: playlist_info[:title]
    )
    track_artist = artist_for(enriched)

    user.tracks.find_or_create_by!(youtube_video_id: item[:video_id]) do |track|
      track.assign_attributes(title: enriched[:title], artist: track_artist, album: album,
        track_number: item[:position] + 1, duration: item[:duration])
    end
  end

  private

  attr_reader :user, :url, :playlist_info

  def artist
    @artist ||= user.artists.find_or_create_by!(name: playlist_info[:channel_name] || "Unknown Artist") do |a|
      a.category = "podcast"
    end
  end

  def album
    @album ||= user.albums.find_or_create_by!(title: playlist_info[:title], artist: artist)
      .tap { |album| adopt_playlist(album) }
  end

  def artist_for(enriched)
    return artist if enriched[:source] == :channel

    user.artists.find_or_create_by!(name: enriched[:artist]) { |a| a.category = "podcast" }
  end
end
