module VideosHelper
  VIDEO_TYPE_LABELS = {"movie" => "Movie", "tv" => "TV"}.freeze

  # The type select's choices; a blank type is "Other".
  def video_type_options = VIDEO_TYPE_LABELS.invert.to_a

  # "Movie · 1999 · comedy, crime", leaving out what the video lacks.
  def video_details(video)
    [VIDEO_TYPE_LABELS[video.video_type], video.year, video.genre_names.join(", ").presence].compact.join(" · ")
  end
end
