class YoutubeMetadataEnricher
  # Brackets: always remove
  BRACKET_NOISE = /\s*\[.*?\]/

  # Parenthesized noise: remove these, but preserve (feat. ...), (Remix), (Live ...), etc.
  PAREN_NOISE = /\s*\((?:official\s+(?:video|audio|music\s+video|lyric\s+video)|lyrics?|audio|video|music\s+video|hd|hq|4k|visuali[sz]er|clip\s+officiel|remastered(?:\s+\d{4})?)\s*\)/i

  # For aggressive search cleaning: strip ALL parens and brackets
  ALL_PARENS_AND_BRACKETS = /\s*(?:\[.*?\]|\(.*?\))/

  # Trailing noise words (without parens/brackets)
  TRAILING_NOISE = /\s*[-|]?\s*(?:official\s+(?:video|audio|music\s+video|lyric\s+video)|lyrics?|hd|hq|4k)\s*$/i

  def self.call(title:, channel_name:, playlist_title: nil)
    new(title, channel_name, playlist_title).call
  end

  def self.clean_for_search(text)
    text.to_s.gsub(ALL_PARENS_AND_BRACKETS, "").gsub(TRAILING_NOISE, "").strip
  end

  def initialize(title, channel_name, playlist_title = nil)
    @title = title.to_s.strip
    @channel_name = channel_name.to_s.strip
    @playlist_title = playlist_title
  end

  # The video title is the best signal, the playlist title the next best, and
  # the channel owner a last resort — a channel owner is rarely the performer.
  def call
    cleaned = clean_title(@title)

    from_video_title(cleaned) || from_playlist_title(cleaned) || from_channel(cleaned)
  end

  private

  def from_video_title(cleaned)
    return nil unless cleaned.include?(" - ")

    artist, title = cleaned.split(" - ", 2).map(&:strip)
    return nil unless artist.present? && title.present?

    {artist: artist, title: title, source: :parsed}
  end

  # Full-album rips name every video after the song alone, leaving the artist
  # in the playlist title.
  def from_playlist_title(cleaned)
    artist = YoutubePlaylistArtist.call(@playlist_title)
    return nil if artist.blank?

    {artist: artist, title: cleaned.presence || @title, source: :playlist}
  end

  def from_channel(cleaned)
    {artist: @channel_name.presence || "Unknown Artist", title: cleaned.presence || @title, source: :channel}
  end

  def clean_title(text)
    text
      .gsub(BRACKET_NOISE, "")
      .gsub(PAREN_NOISE, "")
      .gsub(TRAILING_NOISE, "")
      .strip
  end
end
