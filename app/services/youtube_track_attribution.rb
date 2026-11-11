# Decides who performed one YouTube video, and on which album, from the
# video's own metadata -- never from the owner of the playlist that holds it,
# whose channel name is how "Rock Collection" became an artist.
#
# Sources, strongest first. The tier names which one answered, so a bulk
# repair can trust a release note outright and send a bare title parse to
# MusicBrainz for confirmation:
#
#   :release_note       the "Provided to YouTube by" credit block
#   :channel_confirmed  an "Artist - Title" title on a channel naming that artist
#   :title_only         an "Artist - Title" title on some other channel
#   :playlist           a full-album rip whose playlist title names the artist
#   :channel            nothing named the artist; the video's own channel stands in
#
# Album is set only when the source knows it; the caller picks the fallback.
class YoutubeTrackAttribution
  TOPIC_SUFFIX = " - Topic"

  Result = Data.define(:artist, :title, :album, :year, :tier)

  def self.call(title:, description:, channel_name:, playlist_title:)
    new(title: title, description: description, channel_name: channel_name, playlist_title: playlist_title).call
  end

  def initialize(title:, description:, channel_name:, playlist_title:)
    @title = title
    @description = description
    @channel_name = channel_name
    @playlist_title = playlist_title
  end

  def call
    note = YoutubeReleaseNote.parse(description)
    note ? from_note(note) : from_title(parsed_title)
  end

  private

  attr_reader :title, :description, :channel_name, :playlist_title

  def from_note(note)
    Result.new(artist: note.artist, title: note.title, album: note.album, year: note.year, tier: :release_note)
  end

  def from_title(parsed)
    case parsed[:source]
    when :playlist then credit(parsed, album: playlist_title, tier: :playlist)
    when :channel then credit(parsed, tier: :channel)
    else credit(parsed, tier: title_tier(parsed[:artist]))
    end
  end

  def credit(parsed, tier:, album: nil)
    Result.new(artist: parsed[:artist], title: parsed[:title], album: album, year: nil, tier: tier)
  end

  def title_tier(artist)
    squash(channel_name).include?(squash(artist)) ? :channel_confirmed : :title_only
  end

  def parsed_title
    YoutubeMetadataEnricher.call(title: title, channel_name: channel_artist, playlist_title: playlist_title)
  end

  def channel_artist
    channel_name.to_s.delete_suffix(TOPIC_SUFFIX)
  end

  def squash(name)
    name.to_s.downcase.gsub(/[^[:alnum:]]/, "")
  end
end
