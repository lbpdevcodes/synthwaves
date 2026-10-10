require "rails_helper"

RSpec.describe AlbumMergeService do
  describe ".call" do
    it "moves tracks from source to target album" do
      target = create(:album, title: "Target")
      source = create(:album, title: "Source", user: target.user)
      track = create(:track, album: source, artist: source.artist)

      described_class.call(target: target, source: source)

      expect(track.reload.album).to eq(target)
      expect(track.artist).to eq(target.artist)
    end

    it "destroys the source album" do
      target = create(:album)
      source = create(:album)

      expect {
        described_class.call(target: target, source: source)
      }.to change(Album, :count).by(-1)

      expect(Album.exists?(source.id)).to be false
    end

    it "transfers cover image when target has none" do
      target = create(:album)
      source = create(:album)
      source.cover_image.attach(
        io: StringIO.new("fake image"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )

      described_class.call(target: target, source: source)

      expect(target.reload.cover_image).to be_attached
    end

    it "keeps target cover image when both have one" do
      target = create(:album)
      target.cover_image.attach(
        io: StringIO.new("target image"),
        filename: "target.jpg",
        content_type: "image/jpeg"
      )
      target_blob_id = target.cover_image.blob.id

      source = create(:album)
      source.cover_image.attach(
        io: StringIO.new("source image"),
        filename: "source.jpg",
        content_type: "image/jpeg"
      )

      described_class.call(target: target, source: source)

      expect(target.reload.cover_image.blob.id).to eq(target_blob_id)
    end

    it "raises error when merging album into itself" do
      album = create(:album)

      expect {
        described_class.call(target: album, source: album)
      }.to raise_error(AlbumMergeService::Error, /Cannot merge an album into itself/)
    end

    it "reassigns tracks to the target artist" do
      artist_a = create(:artist, name: "Artist A")
      artist_b = create(:artist, name: "Artist B", user: artist_a.user)
      target = create(:album, artist: artist_a)
      source = create(:album, artist: artist_b)
      track = create(:track, album: source, artist: artist_b)

      described_class.call(target: target, source: source)

      expect(track.reload.artist).to eq(artist_a)
    end
  end
end
