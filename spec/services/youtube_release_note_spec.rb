require "rails_helper"

RSpec.describe YoutubeReleaseNote do
  def description(name)
    file_fixture("youtube/#{name}.txt").read
  end

  describe ".parse" do
    it "returns nil for a description that is not a release note" do
      expect(described_class.parse(description("vevo_busta_rhymes_touch_it"))).to be_nil
    end

    it "reads the title, artist, album and first copyright year from a release note" do
      note = described_class.parse(description("release_note_fleetwood_mac_the_chain"))

      expect(note).to have_attributes(
        title: "The Chain (2004 Remaster)", artist: "Fleetwood Mac", album: "Rumours", year: 1977
      )
    end

    it "credits only the first artist when the note lists featured artists" do
      note = described_class.parse(description("release_note_gorillaz_submission"))

      expect(note.artist).to eq("Gorillaz")
    end

    it "falls back to the release date when the note carries no copyright line" do
      note = described_class.parse("Provided to YouTube by Label\n\nSong · Band\n\nRecord\n\nReleased on: 2001-01-01")

      expect(note.year).to eq(2001)
    end

    it "leaves the year blank when the note dates nothing" do
      note = described_class.parse("Provided to YouTube by Label\n\nSong · Band\n\nRecord")

      expect(note.year).to be_nil
    end

    it "does not read a label's leading digits as the copyright year" do
      note = described_class.parse("Provided to YouTube by DistroKid\n\nCool Ecstasy · Synth.J\n\n" \
        "MIAMI DRIVING 80s Synthwave Music\n\n℗ 7865311 Records DK\n\nReleased on: 2024-09-22")

      expect(note.year).to eq(2024)
    end

    it "returns nil when the credit line names no artist" do
      expect(described_class.parse("Provided to YouTube by Label\n\nJust A Title\n\nRecord")).to be_nil
    end
  end
end
