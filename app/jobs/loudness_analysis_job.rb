class LoudnessAnalysisJob < ApplicationJob
  queue_as :conversion

  def perform(track_id)
    track = Track.find_by(id: track_id)
    return unless track&.audio_file&.attached?

    analyze(track)
  rescue LoudnessAnalyzer::Error => e
    Rails.logger.warn("[LoudnessAnalysisJob] track #{track_id}: #{e.message}")
  end

  private

  def analyze(track)
    track.audio_file.open do |file|
      track.update!(loudness_measurements(file.path))
    end
  end

  def loudness_measurements(path)
    result = LoudnessAnalyzer.call(path)
    {loudness_lufs: result[:integrated_lufs], loudness_gain_db: result[:gain_db]}
  end
end
