module Maintenance
  # One-off repair for YouTube playlist imports that credited the channel
  # owner as the artist. The correction is a reviewed per-track mapping in
  # db/data/channel_artist_retag.yml; this task only walks it.
  #
  # Safe to re-run: the mapping is keyed by track id and each entry writes the
  # same artist and title every time.
  class RetagChannelArtistTracksTask < MaintenanceTasks::Task
    def collection
      Track.where(id: retag.track_ids).order(:id)
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
