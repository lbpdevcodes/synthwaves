# Applies the track edit form. Title, artist, album and year go through
# TrackRetagService, which keeps a track and its album with the same artist.
# The remaining fields are plain attributes. Both parts save in one
# transaction; on failure it returns false with the errors on the track.
#
# Artist and album arrive as typed names. A blank name keeps the current one.
class TrackUpdate
  VALUE_TAGS = {title: :title, release_year: :year}.freeze
  NAME_TAGS = {artist_name: :artist, album_title: :album}.freeze

  def self.call(track, attributes)
    new(track, attributes).call
  end

  def initialize(track, attributes)
    @track = track
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    Track.transaction { retag && track.update!(plain_attributes) }
    true
  rescue ActiveRecord::RecordInvalid => e
    adopt_errors(e.record)
    false
  end

  private

  attr_reader :track, :attributes

  def retag
    retag_tags.empty? || TrackRetagService.call(track: track, **retag_tags)
  end

  def retag_tags
    @retag_tags ||= tags_from(VALUE_TAGS).merge(tags_from(NAME_TAGS).compact_blank)
  end

  def tags_from(fields)
    fields.select { |field, _| attributes.key?(field) }.to_h { |field, tag| [tag, attributes[field]] }
  end

  def plain_attributes
    attributes.except(*VALUE_TAGS.keys, *NAME_TAGS.keys)
  end

  def adopt_errors(record)
    return if record == track

    record.errors.full_messages.each { |message| track.errors.add(:base, message) }
  end
end
