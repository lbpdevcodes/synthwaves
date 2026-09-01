# Reads the artist out of a YouTube playlist title, for full-album rips whose
# video titles are bare song names ("Yaleo", "Fruta Fresca") and so give
# YoutubeMetadataEnricher no "Artist - Title" to parse.
#
# Returns nil whenever the title names no artist. That is the important case:
# a wrong guess here mis-credits a whole album, which is the defect this class
# exists to prevent.
class YoutubePlaylistArtist
  # A rip label leading the title. When one is present the artist, if named at
  # all, sits in parentheses later: "FULL ALBUM - SUPERNATURAL (Santana) (1999)".
  LEADING_LABEL = /\A(?:full\s+album|full\s+cd|album\s+completo|álbum\s+completo|disco\s+completo)\s*[-–—:|]\s*/i

  # Text that describes a release instead of naming an artist. A candidate made
  # only of these is refused, so "Greatest Hits - Juan Luis Guerra" yields nil
  # rather than "Greatest Hits".
  DESCRIPTOR = /\A(?:\d{4}|(?:the\s+)?(?:greatest|best)\s+(?:hits|of)|full\s+album|full\s+cd|album|álbum|disco|completo|lyrics?|lyric|audio|videos?|mix|playlist|hits|remastered|hd|hq|4k)(?:\s+\w+)*\z/i

  def self.call(playlist_title)
    new(playlist_title).call
  end

  def initialize(playlist_title)
    @title = playlist_title.to_s.strip
  end

  def call
    return nil if title.blank?

    title.match?(LEADING_LABEL) ? parenthesised_artist : leading_artist
  end

  private

  attr_reader :title

  # "FULL ALBUM - TAPESTRY (Carole King) (1971)" -> the first parenthetical
  # that names something rather than describing the release.
  def parenthesised_artist
    title.scan(/\(([^)]+)\)/).flatten.filter_map { |candidate| accept(candidate) }.first
  end

  # "Carlos Vives - Déjame entrar (Álbum 2001)" or
  # "Juan Luis Guerra (Greatest Hits Lyrics Videos)".
  def leading_artist
    accept(title[/\A([^-(]+?)\s+-\s+/, 1] || title[/\A([^(]+?)\s*\(/, 1])
  end

  def accept(candidate)
    name = candidate.to_s.strip
    return nil if name.length < 2 || name.match?(DESCRIPTOR)

    name
  end
end
