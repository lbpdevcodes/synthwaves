# Files one uploaded subtitle file on a video: converts it to WebVTT and
# names it from its file name, unless a label is given. A label the video
# already has gets a number ("English 2").
class SubtitleImport
  include ActiveModel::Model

  attr_accessor :video, :filename, :data, :label
  attr_reader :subtitle

  validate :file_chosen

  def save
    return false if invalid?

    @subtitle = video.subtitles.create!(label: unique_label, language: name.language, kind: name.kind,
      vtt: SubtitleText.to_webvtt(data))
    true
  rescue SubtitleText::Unreadable => e
    errors.add(:base, "#{filename}: #{e.message}")
    false
  end

  private

  def file_chosen
    errors.add(:base, "Choose a subtitle file (.srt or .vtt)") if data.blank?
  end

  def unique_label
    taken = video.subtitles.pluck(:label)
    return wanted_label unless taken.include?(wanted_label)

    (2..).lazy.map { |n| "#{wanted_label} #{n}" }.find { |candidate| taken.exclude?(candidate) }
  end

  def wanted_label
    label.presence || name.label
  end

  def name
    @name ||= SubtitleFilename.new(filename, video_basename: video_basename)
  end

  def video_basename
    video.file.filename.base if video.file.attached?
  end
end
