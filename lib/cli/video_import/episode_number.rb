module VideoImport
  # The season and episode a file name numbers (The.Wire.S01E02.mkv,
  # law.and.order.svu.s01.e02.mkv, The.Office.2x05.mkv), sent with the video so
  # the server files it as TV. Both or neither: a lone number is too often part
  # of a title (12.Angry.Men) to read one from a folder of movies.
  module EpisodeNumber
    # S01E02, S01.E02, S01 E02 or S01_E02; and 2x05 only as a word of its own
    # with a two-digit episode, so a picture size (1920x1080) or an aspect
    # ratio (16x9, 4x3) is no episode.
    PATTERNS = [/S(\d+)[ ._]?E(\d+)/i, /(?<![a-z0-9])(\d{1,2})x(\d{2,3})(?![a-z0-9])/i].freeze

    # {season_number:, episode_number:}, or {} when the name numbers no episode.
    def self.from(path)
      name = File.basename(path, ".*")
      match = PATTERNS.lazy.filter_map { |pattern| name.match(pattern) }.first
      match ? {season_number: match[1].to_i, episode_number: match[2].to_i} : {}
    end
  end
end
