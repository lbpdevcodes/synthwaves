# Reads what a subtitle file's name says about it: the label a player shows,
# its language and whether it is captions for deaf viewers.
class SubtitleFilename
  # Marks for subtitles that also describe sounds, for deaf viewers.
  CAPTION_MARKERS = %w[SDH HI CC].freeze
  WORD_BOUNDARY = /\A(?:\z|[ ._-])/

  def initialize(filename, video_basename:)
    @filename = filename
    @video_basename = video_basename
  end

  def label
    return "Subtitles" if tokens.empty?
    return qualifiers.join(" ") unless language_name
    return language_name if qualifiers.empty?

    "#{language_name} (#{qualifiers.join(", ")})"
  end

  def language
    subtitle_language&.code
  end

  def kind
    captions? ? "captions" : "subtitles"
  end

  private

  attr_reader :filename, :video_basename

  def tokens
    @tokens ||= own_name.sub(/\A\d+_/, "").split(".").reject(&:empty?)
  end

  # What the name adds to the video's: "Heat.en.srt" beside Heat.mkv says
  # "en". The video's name must end where a word does: Aliens.srt beside
  # Alien.mkv adds nothing to it.
  def own_name
    stem = File.basename(filename, ".*")
    base = video_basename.to_s
    rest = stem[base.length..]
    (stem.downcase.start_with?(base.downcase) && rest.match?(WORD_BOUNDARY)) ? rest : stem
  end

  def language_token
    (tokens - caption_markers).find { |token| SubtitleLanguage.named(token) }
  end

  def subtitle_language
    SubtitleLanguage.named(language_token) if language_token
  end

  def language_name
    subtitle_language&.name
  end

  def qualifiers
    words = tokens - [language_token]
    captions? ? (words - caption_markers) + ["SDH"] : words
  end

  def captions?
    caption_markers.any?
  end

  def caption_markers
    tokens.select { |token| CAPTION_MARKERS.include?(token.upcase) }
  end
end
