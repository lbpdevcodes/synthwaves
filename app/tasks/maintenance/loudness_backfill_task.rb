module Maintenance
  class LoudnessBackfillTask < MaintenanceTasks::Task
    def collection
      Track.streamable.where(loudness_lufs: nil)
    end

    def count
      collection.count
    end

    def process(track)
      LoudnessAnalysisJob.perform_later(track.id)
    end
  end
end
