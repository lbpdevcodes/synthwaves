# Which of a user's videos the Videos grid shows.
class VideoFilter
  attr_reader :query

  def initialize(query: nil)
    @query = query.presence
  end
end
