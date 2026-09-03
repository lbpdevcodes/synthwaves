require "rails_helper"

RSpec.describe ArtistMergeService do
  def artist_with_album(user, artist_name:, album_title: "Greatest Hits")
    artist = create(:artist, user: user, name: artist_name)
    album = create(:album, user: user, artist: artist, title: album_title)
    [artist, album]
  end

  describe "moving the source's catalogue" do
    it "hands the source's album to the target" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "Sueños Líquidos")
      source, album = artist_with_album(user, artist_name: "Mana", album_title: "Amar es Combatir")

      described_class.call(target: target, source: source)

      expect(album.reload.artist).to eq(target)
    end

    it "moves the tracks on that album to the target" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "Sueños Líquidos")
      source, album = artist_with_album(user, artist_name: "Mana", album_title: "Amar es Combatir")
      track = create(:track, user: user, artist: source, album: album)

      described_class.call(target: target, source: source)

      expect(track.reload.artist).to eq(target)
    end

    # Album validates title uniqueness per artist, so a same-titled album
    # cannot simply change hands.
    it "folds a same-titled album into the target's copy" do
      user = create(:user)
      target, kept = artist_with_album(user, artist_name: "Maná", album_title: "Greatest Hits")
      source, doomed = artist_with_album(user, artist_name: "Mana", album_title: "Greatest Hits")
      track = create(:track, user: user, artist: source, album: doomed)

      described_class.call(target: target, source: source)

      expect(track.reload.album).to eq(kept)
      expect(Album.exists?(doomed.id)).to be false
    end

    # track.artist and track.album.artist are allowed to diverge, and the SYN-2
    # retag created exactly that state.
    it "repoints a track that credits the source but sits on another artist's album" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "Sueños Líquidos")
      source, = artist_with_album(user, artist_name: "Mana", album_title: "Amar es Combatir")
      _, elsewhere = artist_with_album(user, artist_name: "Various", album_title: "Compilation")
      stray = create(:track, user: user, artist: source, album: elsewhere)

      described_class.call(target: target, source: source)

      expect(stray.reload.artist).to eq(target)
      expect(stray.album).to eq(elsewhere)
    end
  end

  describe "what it destroys" do
    it "destroys the source artist" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "A")
      source, = artist_with_album(user, artist_name: "Mana", album_title: "B")

      described_class.call(target: target, source: source)

      expect(Artist.exists?(source.id)).to be false
    end

    # Artist has_many :tracks, dependent: :destroy. Destroying the source
    # before its tracks move would take the music with it.
    it "destroys no tracks" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "A")
      source, album = artist_with_album(user, artist_name: "Mana", album_title: "B")
      create_list(:track, 3, user: user, artist: source, album: album)

      expect { described_class.call(target: target, source: source) }
        .not_to change(Track, :count)
    end
  end

  describe "favorites" do
    it "moves a favorite of the source onto the target" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "A")
      source, = artist_with_album(user, artist_name: "Mana", album_title: "B")
      favorite = create(:favorite, user: user, favorable: source)

      described_class.call(target: target, source: source)

      expect(favorite.reload.favorable).to eq(target)
    end

    # favorites carries a unique index on user + favorable type + favorable id.
    it "drops the source favorite when the target is already favorited" do
      user = create(:user)
      target, = artist_with_album(user, artist_name: "Maná", album_title: "A")
      source, = artist_with_album(user, artist_name: "Mana", album_title: "B")
      create(:favorite, user: user, favorable: target)
      duplicate = create(:favorite, user: user, favorable: source)

      described_class.call(target: target, source: source)

      expect(Favorite.exists?(duplicate.id)).to be false
      expect(user.favorites.where(favorable_type: "Artist").count).to eq(1)
    end
  end

  describe "what it refuses" do
    it "refuses to merge an artist into itself" do
      artist, = artist_with_album(create(:user), artist_name: "Mana")

      expect { described_class.call(target: artist, source: artist) }
        .to raise_error(described_class::Error, /itself/)
    end

    it "refuses to merge across libraries" do
      target, = artist_with_album(create(:user), artist_name: "Maná")
      source, = artist_with_album(create(:user), artist_name: "Mana")

      expect { described_class.call(target: target, source: source) }
        .to raise_error(described_class::Error)
      expect(Artist.exists?(source.id)).to be true
    end
  end
end
