module VideosHelper
  VIDEO_TYPE_LABELS = {"movie" => "Movie", "tv" => "TV"}.freeze
  # The Videos grid's type choices (VideoFilter::TYPES), by param.
  VIDEO_TYPE_FILTERS = {"" => "All", "movie" => "Movies", "tv" => "TV", "other" => "Other"}.freeze

  # The type select's choices; a blank type is "Other".
  def video_type_options = VIDEO_TYPE_LABELS.invert.to_a

  # "Movie · 1999 · comedy, crime", leaving out what the video lacks.
  def video_details(video)
    [VIDEO_TYPE_LABELS[video.video_type], video.year, video.genre_names.join(", ").presence].compact.join(" · ")
  end
end
