# Files a batch of direct-uploaded audio files as tracks in one album: the
# album given, or the artist's album with the typed title (created if new).
# Each track starts titled by its file name. MetadataExtractionJob then reads
# the tags, except for formats AudioConversionJob converts, which reads them
# itself while it swaps the file.
class TrackUpload
  include ActiveModel::Model

  attr_accessor :album, :artist, :album_title, :signed_blob_ids
  attr_reader :tracks

  validate :files_chosen
  validates :album_title, presence: true, unless: :album

  def save
    return false if invalid?

    Track.transaction { @tracks = blobs.map { |blob| create_track(blob) } }
    tracks.each { |track| read_tags_later(track) }
    true
  end

  def destination
    @destination ||= album || artist.user.albums.find_or_create_by!(title: album_title, artist: artist)
  end

  def artist_album_titles
    artist.albums.order(:title).pluck(:title)
  end

  private

  def blobs
    @blobs ||= Array(signed_blob_ids).filter_map { |id| ActiveStorage::Blob.find_signed(id) }
  end

  def files_chosen
    errors.add(:base, "Choose at least one audio file") if blobs.empty?
  end

  def create_track(blob)
    destination.tracks.create!(title: blob.filename.base, user: destination.user, artist: destination.artist,
      file_format: blob.filename.extension_without_delimiter.downcase, file_size: blob.byte_size, audio_file: blob)
  end

  def read_tags_later(track)
    MetadataExtractionJob.perform_later(track.id) unless AudioConversionJob::CONVERTIBLE_FORMATS.include?(track.file_format)
  end
end
