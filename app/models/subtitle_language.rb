# The languages subtitle file names spell out, by ISO 639-1 code, English
# name, or the ISO 639-2 codes releases use ("eng", "fre", "fra").
class SubtitleLanguage < Data.define(:code, :name)
  LIST = [
    %w[ar Arabic ara],
    %w[bg Bulgarian bul],
    %w[ca Catalan cat],
    %w[cs Czech cze ces],
    %w[da Danish dan],
    %w[de German ger deu],
    %w[el Greek gre ell],
    %w[en English eng],
    %w[es Spanish spa],
    %w[et Estonian est],
    %w[fa Persian per fas Farsi],
    %w[fi Finnish fin],
    %w[fr French fre fra],
    %w[he Hebrew heb],
    %w[hi Hindi hin],
    %w[hr Croatian hrv],
    %w[hu Hungarian hun],
    %w[id Indonesian ind],
    %w[is Icelandic ice isl],
    %w[it Italian ita],
    %w[ja Japanese jpn],
    %w[ko Korean kor],
    %w[lt Lithuanian lit],
    %w[lv Latvian lav],
    %w[ms Malay may msa],
    %w[nl Dutch dut nld],
    %w[no Norwegian nor nob nno],
    %w[pl Polish pol],
    %w[pt Portuguese por],
    %w[ro Romanian rum ron],
    %w[ru Russian rus],
    %w[sk Slovak slo slk],
    %w[sl Slovenian slv],
    %w[sr Serbian srp],
    %w[sv Swedish swe],
    %w[th Thai tha],
    %w[tl Tagalog tgl Filipino fil],
    %w[tr Turkish tur],
    %w[uk Ukrainian ukr],
    %w[vi Vietnamese vie],
    %w[zh Chinese chi zho]
  ].freeze

  BY_WORD = LIST.each_with_object({}) do |(code, name, *codes), table|
    language = new(code:, name:)
    [code, name, *codes].each { |word| table[word.downcase] = language }
  end.freeze

  def self.named(word) = BY_WORD[word.downcase]
end
