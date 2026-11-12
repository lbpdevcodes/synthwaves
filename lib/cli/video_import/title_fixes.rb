module VideoImport
  # Corrections to the titles read from file names, kept in the folder's
  # synthwaves-titles.txt, one per line: "Theres Something About Mary =
  # There's Something About Mary". Blank lines and # comments are skipped.
  class TitleFixes
    FILE = "synthwaves-titles.txt".freeze

    def self.in(folder)
      path = File.join(folder, FILE)
      new(File.file?(path) ? File.readlines(path, chomp: true) : [])
    end

    def initialize(lines)
      @fixes = lines.reject { |line| line.strip.empty? || line.start_with?("#") }
        .to_h { |line| line.split("=", 2).map(&:strip) }
    end

    def apply(title) = @fixes.fetch(title, title)
  end
end
