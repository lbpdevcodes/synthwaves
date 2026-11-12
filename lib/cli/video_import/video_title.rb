module VideoImport
  # A video's title, read from a release file name: the words before the
  # release year, or before the first quality tag when there is no year.
  # Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv is "Dazed and Confused".
  class VideoTitle
    YEAR = /\A[(\[]?(19|20)\d\d[)\]]?\z/
    QUALITY = /\A[(\[]?(\d{3,4}p|bluray|brrip|bdrip|web-?dl|webrip|hdtv|dvdrip|x26[45]|h\.?26[45]|hevc)[)\]]?\z/i
    EDITIONS = %w[extended cut unrated remastered proper directors theatrical repack].freeze
    SMALL_WORDS = %w[a an and at for in of on or the to with].freeze

    def self.from(filename) = new(filename).to_s

    def initialize(filename)
      @words = File.basename(filename, ".*").split(/[ ._]+/).reject(&:empty?)
    end

    def to_s = words.each_with_index.map { |word, at| styled(word, at) }.join(" ")

    private

    def words = title_words.empty? ? @words : title_words

    def title_words = @words.take(length).reverse.drop_while { |word| EDITIONS.include?(word.downcase) }.reverse

    # The last year ahead of the quality tags ends the title. A year that
    # opens the name is the title itself (1917).
    def length
      tags = @words.index { |word| word.match?(QUALITY) } || @words.size
      year = @words.take(tags).rindex { |word| word.match?(YEAR) }
      year&.positive? ? year : tags
    end

    def styled(word, at)
      return word.downcase if at.positive? && SMALL_WORDS.include?(word.downcase)

      (word == word.downcase) ? word.capitalize : word
    end
  end
end
