# Which of a user's videos the Videos grid shows: those matching a search, a
# type and a genre, each optional. VideoLibrary runs the search itself, since
# it reaches into collections.
class VideoFilter
  # The type choices, by the param that picks each. Other is a video with no type.
  TYPES = {"movie" => "movie", "tv" => "tv", "other" => nil}.freeze

  attr_reader :query, :type, :genre

  def initialize(query: nil, type: nil, genre: nil)
    @query = query.presence
    @type = type.presence_in(TYPES.keys)
    @genre = genre.presence
  end

  def active? = query.present? || narrows?

  # A type or genre leaves out the collections with nothing to match inside.
  def narrows? = type.present? || genre.present?

  # These videos, narrowed to the type and genre.
  def apply(videos)
    videos = videos.where(video_type: TYPES[type]) if type
    genre ? videos.by_genre(genre) : videos
  end
end
