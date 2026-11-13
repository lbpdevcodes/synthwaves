# What a video's frame size is called: 4K, 1080p, 720p or SD. A video takes
# the highest name that either side reaches, so a letterboxed 1920×800 film
# and a 1440×1080 4:3 transfer are both 1080p. Each minimum sits a little
# under the nominal size, for encodes cropped by a few pixels (1916×1036).
module VideoResolution
  # Highest first: name => [minimum width, minimum height].
  BUCKETS = {"4K" => [3800, 2100], "1080p" => [1900, 1000], "720p" => [1260, 700]}.freeze
  # Every name, biggest first.
  NAMES = [*BUCKETS.keys, "SD"].freeze

  # Nil when the video's size isn't known.
  def self.label(width:, height:)
    return unless width && height

    BUCKETS.find { |_, (min_width, min_height)| width >= min_width || height >= min_height }&.first || "SD"
  end
end
