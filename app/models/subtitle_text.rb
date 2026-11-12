# Turns the bytes of an SRT or WebVTT file into WebVTT text, the only subtitle
# format a browser's <track> plays.
class SubtitleText
  class Unreadable < StandardError; end

  # A cue timing in either format: SRT puts a comma before the milliseconds,
  # WebVTT a dot and may leave out the hours.
  CUE_TIMING = /^(?:\d+:)?\d{2}:\d{2}[,.]\d{3} --> /
  TIMING = /^(\d+:\d{2}:\d{2}),(\d{3}) --> (\d+:\d{2}:\d{2}),(\d{3})/
  # SRT players honour these; a WebVTT player would print them as text.
  UNSUPPORTED_MARKUP = /<\/?font[^>]*>|\{\\[^}]*\}/i
  BARE_AMPERSAND = /&(?!(?:[a-z]+|#\d+|#x\h+);)/i
  STRAY_LESS_THAN = /<(?!\/?[ibu]>)/
  BYTE_ORDER_MARKS = {
    "\xEF\xBB\xBF".b => Encoding::UTF_8,
    "\xFF\xFE".b => Encoding::UTF_16LE,
    "\xFE\xFF".b => Encoding::UTF_16BE
  }.freeze

  def self.to_webvtt(source) = new(source).to_webvtt

  def initialize(source)
    @source = source
  end

  def to_webvtt
    raise Unreadable, "no subtitle cues found" unless text.match?(CUE_TIMING)
    return text if text.start_with?("WEBVTT")

    "WEBVTT\n\n" + from_srt
  end

  private

  attr_reader :source

  def from_srt
    text.gsub(TIMING, '\1.\2 --> \3.\4')
      .gsub(UNSUPPORTED_MARKUP, "")
      .gsub(BARE_AMPERSAND, "&amp;")
      .gsub(STRAY_LESS_THAN, "&lt;")
  end

  def text
    @text ||= decoded.gsub(/\r\n?/, "\n")
  end

  def decoded
    mark, encoding = BYTE_ORDER_MARKS.find { |bom, _| bytes.start_with?(bom) }
    mark ? read(bytes.delete_prefix(mark), encoding) : read_unmarked
  end

  # Without a mark, text that is not valid UTF-8 is most likely Windows-1252.
  def read_unmarked
    utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
    utf8.valid_encoding? ? utf8 : read(bytes, Encoding::Windows_1252)
  end

  def read(raw, encoding)
    raw.dup.force_encoding(encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end

  def bytes
    @bytes ||= source.b
  end
end
