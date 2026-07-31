class TrackAudioAttachmentService
  def self.call(track:, file_path:, filename:)
    new(track: track, file_path: file_path, filename: filename).call
  end

  def initialize(track:, file_path:, filename:)
    @track = track
    @file_path = file_path
    @filename = filename
  end

  def call
    attach_audio
    apply_metadata
  end

  private

  attr_reader :track, :file_path, :filename

  def attach_audio
    track.audio_file.attach(
      io: File.open(file_path),
      filename: filename,
      content_type: Marcel::MimeType.for(name: filename.to_s)
    )
  end

  def apply_metadata
    metadata = extract_metadata
    track.update!(
      download_status: "completed",
      download_error: nil,
      duration: metadata[:duration] || track.duration,
      bitrate: metadata[:bitrate] || track.bitrate,
      file_format: filename[/\.\w+$/]&.delete("."),
      file_size: File.size(file_path)
    )
    metadata
  end

  def extract_metadata
    MetadataExtractor.call(file_path)
  rescue WahWah::WahWahArgumentError
    {}
  end
end
