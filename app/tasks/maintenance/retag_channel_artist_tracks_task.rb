module Maintenance
  # One-off repair for YouTube playlist imports that credited the channel
  # owner as the artist. The correction is a reviewed per-track mapping in
  # db/data/channel_artist_retag.yml; this task only walks it.
  #
  # Safe to re-run: the mapping is keyed by track id and each entry writes the
  # same artist and title every time.
  class RetagChannelArtistTracksTask < MaintenanceTasks::Task
    # No order clause here. MaintenanceTasks hands this relation to
    # job-iteration, which refuses one that carries its own ORDER BY and then
    # reorders by primary key to drive the cursor. Id order is kept either way.
    def collection
      Track.where(id: retag.track_ids)
    end

    def count
      collection.count
    end

    def process(track)
      retag.apply(track)
    end

    private

    def retag
      @retag ||= ChannelArtistRetag.load
    end
  end
end
