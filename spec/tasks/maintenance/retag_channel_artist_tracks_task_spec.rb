require "rails_helper"

RSpec.describe Maintenance::RetagChannelArtistTracksTask do
  let(:task) { described_class.new }
  let(:retag) { ChannelArtistRetag.load }
  let(:mapped_id) { retag.track_ids.first }

  # Ids are explicit: the mapping is keyed by real library ids, so a track
  # left to auto-increment can land on a mapped id and skew the counts.
  let(:unmapped_id) { 999_999 }

  def channel_track(id:, user:, channel: "Diego Pradilla")
    artist = create(:artist, user: user, name: channel)
    album = create(:album, user: user, artist: artist)
    create(:track, id: id, user: user, artist: artist, album: album, title: "Some - Video Title")
  end

  describe "#collection" do
    it "includes a track the shipped mapping names" do
      track = channel_track(id: mapped_id, user: create(:user))

      expect(task.collection).to include(track)
    end

    it "excludes a track the mapping does not name" do
      other = channel_track(id: unmapped_id, user: create(:user))

      expect(task.collection).not_to include(other)
    end
  end

  describe "#count" do
    it "counts only the mapped tracks that exist in the library" do
      user = create(:user)
      channel_track(id: mapped_id, user: user)
      channel_track(id: unmapped_id, user: user, channel: "Some Other Channel")

      expect(task.count).to eq(1)
    end
  end

  describe "#process" do
    it "retags the track to the artist the shipped mapping names" do
      track = channel_track(id: mapped_id, user: create(:user))

      task.process(track)

      expect(track.reload.artist.name).to eq(retag.entries.fetch(mapped_id).fetch("artist"))
    end

    it "leaves no track credited to one of the channel names" do
      track = channel_track(id: mapped_id, user: create(:user))

      task.process(track)

      expect(ChannelArtistRetag::CHANNEL_NAMES).not_to include(track.reload.artist.name)
    end
  end

  # The specs above call collection, count and process directly, which never
  # builds a cursor. MaintenanceTasks does not run a relation that way: it hands
  # it to job-iteration, which refuses any relation carrying its own ORDER BY,
  # then reorders by primary key itself.
  describe "the collection as the job runner consumes it" do
    it "iterates under a cursor the way MaintenanceTasks runs it" do
      track = channel_track(id: mapped_id, user: create(:user))

      enumerator = JobIteration::EnumeratorBuilder
        .new(nil)
        .active_record_on_records(task.collection, cursor: nil)

      expect(enumerator.map { |record, _cursor| record }).to eq([track])
    end

    # The acceptance criterion on SYN-2, driven through the real enumerator
    # rather than by calling process on a track picked by hand.
    it "leaves no track credited to a channel name after a full pass" do
      user = create(:user)
      # One artist row for all five: Artist validates name uniqueness, and the
      # real library had one channel row owning many tracks.
      channel = create(:artist, user: user, name: "Diego Pradilla")
      album = create(:album, user: user, artist: channel)
      retag.track_ids.first(5).each do |id|
        create(:track, id: id, user: user, artist: channel, album: album, title: "Some - Video Title")
      end

      JobIteration::EnumeratorBuilder
        .new(nil)
        .active_record_on_records(task.collection, cursor: nil)
        .each { |track, _cursor| task.process(track) }

      credited_to_channel = Track.joins(:artist)
        .where(artists: {name: ChannelArtistRetag::CHANNEL_NAMES})

      expect(credited_to_channel).to be_empty
    end
  end
end
