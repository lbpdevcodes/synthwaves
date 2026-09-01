require "rails_helper"

RSpec.describe YoutubePlaylistArtist do
  describe ".call" do
    context "when the playlist title leads with the artist" do
      it "reads the artist before the dash" do
        expect(described_class.call("Carlos Vives - Déjame entrar (Álbum 2001)")).to eq("Carlos Vives")
      end

      it "ignores a trailing full-album marker" do
        expect(described_class.call("Carlos Vives - El Amor De Mi Tierra (Full Album)")).to eq("Carlos Vives")
      end

      it "reads the artist before a descriptive parenthetical" do
        expect(described_class.call("Juan Luis Guerra (Greatest Hits Lyrics Videos)")).to eq("Juan Luis Guerra")
      end
    end

    context "when a full-album label leads and the artist is parenthesised" do
      it "reads the artist from the parentheses, not the album name" do
        expect(described_class.call("FULL ALBUM - SUPERNATURAL (Santana) (1999)")).to eq("Santana")
      end

      it "skips a parenthesised year" do
        expect(described_class.call("FULL ALBUM - TAPESTRY (Carole King) (1971)")).to eq("Carole King")
      end
    end

    context "when the title names no artist" do
      it "returns nil for a genre compilation" do
        expect(described_class.call("90s Latin Music")).to be_nil
      end

      it "returns nil for a descriptive compilation" do
        expect(described_class.call("clasicos rock en español")).to be_nil
      end

      it "returns nil when the artist is buried with no separator" do
        expect(described_class.call("los rodriguez palabras mas o menos full album")).to be_nil
      end

      it "returns nil for blank input" do
        expect(described_class.call(nil)).to be_nil
        expect(described_class.call("   ")).to be_nil
      end

      it "returns nil when the leading segment is only a label" do
        expect(described_class.call("FULL ALBUM - Greatest Hits")).to be_nil
      end
    end
  end
end
