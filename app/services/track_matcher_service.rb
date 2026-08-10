# Resolves a free-form "Artist - Title" or bare-title query to the best-matching
# track in the user's library. Exact = case-insensitive full-title match (the
# artist hint must match too when present); partial = title substring. Case
# insensitivity is ASCII-only (SQLite LOWER/LIKE), consistent with SearchService.
class TrackMatcherService
  Result = Data.define(:track, :confidence)

  def self.call(user:, query:)
    new(user:, query:).call
  end

  def initialize(user:, query:)
    @user = user
    @artist_hint, @title_hint = split_query(query.to_s.strip)
  end

  def call
    track = exact_match
    return Result.new(track:, confidence: "exact") if track

    track = partial_match
    return Result.new(track:, confidence: "partial") if track

    Result.new(track: nil, confidence: nil)
  end

  private

  attr_reader :user, :artist_hint, :title_hint

  # Same " - " (limit 2) split as YoutubeMetadataEnricher.
  def split_query(query)
    if query.include?(" - ")
      artist, title = query.split(" - ", 2).map(&:strip)
      return [artist, title] if artist.present? && title.present?
    end
    [nil, query]
  end

  def exact_match
    scope = user.tracks.includes(:artist).where("LOWER(tracks.title) = ?", title_hint.downcase)
    return scope.first unless artist_hint

    scope.detect { |track| track.artist.name.casecmp?(artist_hint) }
  end

  def partial_match
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(title_hint)}%"
    scope = user.tracks.includes(:artist).where("tracks.title LIKE ? ESCAPE '\\'", pattern)
    return scope.first unless artist_hint

    artist_pattern = /#{Regexp.escape(artist_hint)}/i
    scope.detect { |track| track.artist.name.match?(artist_pattern) } || scope.first
  end
end
