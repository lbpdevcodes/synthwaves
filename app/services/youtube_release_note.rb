# Reads the credit block that YouTube's auto-generated "Topic" uploads carry
# in their description:
#
#   Provided to YouTube by Epic
#
#   Don't Look Back · Boston
#
#   Don't Look Back
#
#   ℗ 1978 Epic Records, a division of Sony Music Entertainment
#
# The credit line names the song, then its performers; the first performer is
# the artist and featured ones are dropped. The next line is the album. The
# year is the first ℗ year, or the "Released on" year when the ℗ line holds no
# real year -- a label can start with digits ("℗ 7865311 Records DK"). Anything
# else is not a release note.
class YoutubeReleaseNote
  PREFIX = "Provided to YouTube by"
  CREDIT_SEPARATOR = " · "
  COPYRIGHT_YEAR = /℗ (\d{4})(?!\d)/
  RELEASE_YEAR = /^Released on: (\d{4})-/
  EARLIEST_YEAR = 1900

  Note = Data.define(:title, :artist, :album, :year)

  def self.parse(description)
    lines = description.to_s.lines.map(&:strip).reject(&:empty?)
    return unless lines.first.to_s.start_with?(PREFIX)

    from_lines(lines, year: year_in(description))
  end

  def self.year_in(description)
    [COPYRIGHT_YEAR, RELEASE_YEAR].lazy.filter_map { |pattern| plausible(description[pattern, 1]) }.first
  end

  def self.plausible(digits)
    year = digits&.to_i
    year if year&.between?(EARLIEST_YEAR, Date.current.year + 1)
  end

  def self.from_lines(lines, year:)
    title, artist = lines[1].to_s.split(CREDIT_SEPARATOR)
    Note.new(title: title, artist: artist, album: lines[2], year: year) if artist.present?
  end
  private_class_method :from_lines, :year_in, :plausible
end
