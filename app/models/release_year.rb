# The release year in a video's file name: the last year ahead of the
# quality tags (Blade.Runner.2049.2017.1080p is 2017). A year that opens the
# name is the title, not the year (1917.2019 is 2019).
#
# The same rule ends a title in bin/import_videos (VideoImport::VideoTitle).
# That copy stays stdlib-only in lib/cli, which Rails never loads.
class ReleaseYear
  YEAR = /\A[(\[]?((?:19|20)\d\d)[)\]]?\z/
  QUALITY = /\A[(\[]?(\d{3,4}p|bluray|brrip|bdrip|web-?dl|webrip|hdtv|dvdrip|x26[45]|h\.?26[45]|hevc)[)\]]?\z/i

  def self.from(filename) = new(filename).year

  def initialize(filename)
    @words = File.basename(filename.to_s, ".*").split(/[ ._]+/).reject(&:empty?)
  end

  def year
    at = before_tags.rindex { |word| word.match?(YEAR) }
    @words[at][YEAR, 1].to_i if at&.positive?
  end

  private

  def before_tags = @words.take(@words.index { |word| word.match?(QUALITY) } || @words.size)
end
