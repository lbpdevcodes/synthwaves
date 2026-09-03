# Reviewed, per-track repair for YouTube playlist imports that credited the
# channel owner as the artist and left the real artist in the video title.
#
# The mapping is keyed by track id, never by channel name, because one channel
# carries more than one artist: "PamelaGC" holds both Santana's Supernatural
# and Carole King's Tapestry, so a per-artist rename would credit Tapestry to
# Santana. Where the title names only the band, the entry corrects the artist
# and leaves the title for a person to identify.
class ChannelArtistRetag
  DEFAULT_PATH = Rails.root.join("db/data/channel_artist_retag.yml")

  # The bogus artists this mapping exists to empty. Nothing may map back to one.
  CHANNEL_NAMES = [
    "Diego Pradilla", "Andersson solorzano niño", "World Circuit Records",
    "Karen Records", "kyliechikk", "Play List Music", "PamelaGC", "Ariel",
    "The Radio Oficial", "Vicente Fernández - Topic",
    "LA REBELION (NO LE PEGUE A LA NEGRA)"
  ].freeze

  def self.load(path = DEFAULT_PATH)
    new(YAML.safe_load_file(path))
  end

  def initialize(entries)
    @entries = entries
  end

  attr_reader :entries

  def track_ids
    entries.keys
  end

  def apply(track)
    entry = entries.fetch(track.id)

    track.update!(
      artist: artist_for(track.user, entry.fetch("artist")),
      title: entry.fetch("title", track.title)
    )
  end

  private

  def artist_for(user, name)
    Artist.find_or_create_named!(user, name)
  end
end
