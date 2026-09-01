require "rails_helper"

RSpec.describe YoutubeMetadataEnricher do
  describe ".call" do
    it "parses 'Artist - Song' format" do
      result = described_class.call(title: "Daft Punk - Around The World", channel_name: "DaftPunkVEVO")

      expect(result[:artist]).to eq("Daft Punk")
      expect(result[:title]).to eq("Around The World")
      expect(result[:source]).to eq(:parsed)
    end

    it "strips parenthesized noise and parses" do
      result = described_class.call(title: "Daft Punk - Around The World (Official Video)", channel_name: "DaftPunkVEVO")

      expect(result[:artist]).to eq("Daft Punk")
      expect(result[:title]).to eq("Around The World")
      expect(result[:source]).to eq(:parsed)
    end

    it "strips bracketed noise and parses" do
      result = described_class.call(title: "Daft Punk - Around The World [Official Audio]", channel_name: "DaftPunkVEVO")

      expect(result[:artist]).to eq("Daft Punk")
      expect(result[:title]).to eq("Around The World")
      expect(result[:source]).to eq(:parsed)
    end

    it "preserves feat. in title" do
      result = described_class.call(title: "Artist - Song (feat. Other)", channel_name: "Channel")

      expect(result[:title]).to eq("Song (feat. Other)")
      expect(result[:source]).to eq(:parsed)
    end

    it "preserves Remix in title" do
      result = described_class.call(title: "Artist - Song (Remix)", channel_name: "Channel")

      expect(result[:title]).to eq("Song (Remix)")
    end

    it "preserves Live in title" do
      result = described_class.call(title: "Artist - Song (Live at Wembley)", channel_name: "Channel")

      expect(result[:title]).to eq("Song (Live at Wembley)")
    end

    it "falls back to channel_name when no dash" do
      result = described_class.call(title: "Song Without Dash", channel_name: "ArtistChannel")

      expect(result[:artist]).to eq("ArtistChannel")
      expect(result[:title]).to eq("Song Without Dash")
      expect(result[:source]).to eq(:channel)
    end

    it "splits on first dash only" do
      result = described_class.call(title: "Artist - Song - Extra Dashes", channel_name: "Channel")

      expect(result[:artist]).to eq("Artist")
      expect(result[:title]).to eq("Song - Extra Dashes")
      expect(result[:source]).to eq(:parsed)
    end

    it "strips multiple noise patterns" do
      result = described_class.call(
        title: "Artist - Song [HD] (Official Video) (Lyrics)",
        channel_name: "Channel"
      )

      expect(result[:artist]).to eq("Artist")
      expect(result[:title]).to eq("Song")
    end

    it "strips remastered year noise" do
      result = described_class.call(title: "Artist - Song (Remastered 2023)", channel_name: "Channel")

      expect(result[:artist]).to eq("Artist")
      expect(result[:title]).to eq("Song")
    end

    it "handles empty title" do
      result = described_class.call(title: "", channel_name: "Channel")

      expect(result[:artist]).to eq("Channel")
      expect(result[:source]).to eq(:channel)
    end

    it "handles nil title" do
      result = described_class.call(title: nil, channel_name: "Channel")

      expect(result[:artist]).to eq("Channel")
      expect(result[:source]).to eq(:channel)
    end

    it "handles nil channel_name with no dash" do
      result = described_class.call(title: "Some Song", channel_name: nil)

      expect(result[:artist]).to eq("Unknown Artist")
      expect(result[:title]).to eq("Some Song")
    end

    it "handles music video noise" do
      result = described_class.call(title: "Artist - Song (Music Video)", channel_name: "Channel")

      expect(result[:artist]).to eq("Artist")
      expect(result[:title]).to eq("Song")
    end

    it "strips trailing noise words without parens" do
      result = described_class.call(title: "Artist - Song Official Video", channel_name: "Channel")

      expect(result[:artist]).to eq("Artist")
      expect(result[:title]).to eq("Song")
    end
  end

  describe ".call with a playlist title" do
    it "credits the playlist artist when the video title names no artist" do
      result = described_class.call(title: "Yaleo", channel_name: "PamelaGC",
        playlist_title: "FULL ALBUM - SUPERNATURAL (Santana) (1999)")

      expect(result[:artist]).to eq("Santana")
      expect(result[:title]).to eq("Yaleo")
      expect(result[:source]).to eq(:playlist)
    end

    it "prefers the artist in the video title over the playlist title" do
      result = described_class.call(title: "Shakira - Inevitable", channel_name: "Diego Pradilla",
        playlist_title: "Carlos Vives - El Amor De Mi Tierra (Full Album)")

      expect(result[:artist]).to eq("Shakira")
      expect(result[:source]).to eq(:parsed)
    end

    it "falls back to the channel when the playlist title names no artist" do
      result = described_class.call(title: "TEMBLANDO", channel_name: "Andersson solorzano niño",
        playlist_title: "clasicos rock en español")

      expect(result[:artist]).to eq("Andersson solorzano niño")
      expect(result[:source]).to eq(:channel)
    end

    it "falls back to the channel when no playlist title is given" do
      result = described_class.call(title: "Song Without Dash", channel_name: "ArtistChannel")

      expect(result[:artist]).to eq("ArtistChannel")
      expect(result[:source]).to eq(:channel)
    end
  end

  describe ".clean_for_search" do
    it "strips all parenthesized and bracketed content" do
      result = described_class.clean_for_search("Song (feat. Other) [Deluxe Edition]")

      expect(result).to eq("Song")
    end

    it "strips trailing noise words" do
      result = described_class.clean_for_search("Song Official Video")

      expect(result).to eq("Song")
    end

    it "handles empty string" do
      expect(described_class.clean_for_search("")).to eq("")
    end

    it "handles nil" do
      expect(described_class.clean_for_search(nil)).to eq("")
    end
  end
end
