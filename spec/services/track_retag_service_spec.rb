require "rails_helper"

RSpec.describe TrackRetagService do
  # A YouTube-import shape: the channel owner credited as artist, the real
  # artist buried in the title, and the album named after the channel's upload.
  def channel_track(user, artist_name: "Diego Pradilla", album_title: "90s Latin Music")
    artist = create(:artist, user: user, name: artist_name)
    album = create(:album, user: user, artist: artist, title: album_title)
    create(:track, user: user, artist: artist, album: album,
      title: "Shakira - Inevitable (Official HD Video)")
  end

  describe "the tags it writes" do
    it "sets the title, the artist and the year" do
      track = channel_track(create(:user))

      described_class.call(track: track, title: "Inevitable", artist: "Shakira", year: 1998)

      expect(track.reload).to have_attributes(title: "Inevitable", release_year: 1998)
      expect(track.artist.name).to eq("Shakira")
    end

    it "leaves an omitted tag alone" do
      track = channel_track(create(:user))

      described_class.call(track: track, artist: "Shakira")

      expect(track.reload.title).to eq("Shakira - Inevitable (Official HD Video)")
    end

    it "refuses an edit that names no tag at all" do
      track = channel_track(create(:user))

      expect { described_class.call(track: track) }.to raise_error(ArgumentError)
    end
  end

  describe "resolving the artist" do
    it "joins an artist that differs only in case instead of creating a twin" do
      user = create(:user)
      existing = create(:artist, user: user, name: "CAIFANES")
      track = channel_track(user)

      expect { described_class.call(track: track, artist: "Caifanes") }
        .not_to change(Artist, :count)
      expect(track.reload.artist).to eq(existing)
    end

    it "creates the artist when the user has none by that name" do
      user = create(:user)
      track = channel_track(user)

      expect { described_class.call(track: track, artist: "Shakira") }
        .to change { user.artists.count }.by(1)
      expect(track.reload.artist.name).to eq("Shakira")
    end

    it "never borrows another user's artist" do
      user = create(:user)
      create(:artist, user: create(:user), name: "Shakira")
      track = channel_track(user)

      described_class.call(track: track, artist: "Shakira")

      expect(track.reload.artist.user).to eq(user)
    end
  end

  describe "the album following the artist" do
    it "re-homes the album under the new artist, keeping its title" do
      track = channel_track(create(:user))

      described_class.call(track: track, artist: "Shakira")

      expect(track.reload.album.title).to eq("90s Latin Music")
      expect(track.album.artist).to eq(track.artist)
    end

    it "moves the track to the named album under the new artist" do
      track = channel_track(create(:user))

      described_class.call(track: track, artist: "Santana", album: "Supernatural")

      expect(track.reload.album.title).to eq("Supernatural")
      expect(track.album.artist.name).to eq("Santana")
    end

    it "joins an album the new artist already owns" do
      user = create(:user)
      santana = create(:artist, user: user, name: "Santana")
      supernatural = create(:album, user: user, artist: santana, title: "Supernatural")
      track = channel_track(user)

      expect { described_class.call(track: track, artist: "Santana", album: "Supernatural") }
        .not_to change(Album, :count)
      expect(track.reload.album).to eq(supernatural)
    end

    it "leaves the album alone when only the title changes" do
      track = channel_track(create(:user))
      album = track.album

      expect { described_class.call(track: track, title: "Inevitable") }
        .not_to change(Album, :count)
      expect(track.reload.album).to eq(album)
    end
  end

  describe "re-running the same edit" do
    it "changes nothing the second time" do
      track = channel_track(create(:user))
      edit = {title: "Inevitable", artist: "Shakira", album: "Pies Descalzos", year: 1995}
      described_class.call(track: track, **edit)

      expect { described_class.call(track: track.reload, **edit) }
        .not_to change { [Artist.count, Album.count] }
      expect(track.reload).to have_attributes(title: "Inevitable", release_year: 1995)
    end
  end
end
