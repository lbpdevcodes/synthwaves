# One subtitle track of a video, stored as WebVTT so the page can serve it
# from its own origin to a <track> element.
class VideoSubtitle < ApplicationRecord
  KINDS = %w[subtitles captions].freeze

  belongs_to :video

  validates :label, presence: true, uniqueness: {scope: :video_id}
  validates :kind, inclusion: {in: KINDS}
  validates :vtt, presence: true
end
