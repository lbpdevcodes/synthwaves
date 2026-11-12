# Files directly uploaded video blobs in a folder, one video per blob,
# reading each file name for its season, episode and title.
class FolderVideoUploadService
  def self.call(folder:, signed_blob_ids:, filenames:, season_number: nil)
    new(folder: folder, signed_blob_ids: signed_blob_ids, filenames: filenames, season_number: season_number).call
  end

  def initialize(folder:, signed_blob_ids:, filenames:, season_number: nil)
    @folder = folder
    @signed_blob_ids = signed_blob_ids
    @filenames = filenames
    @season_number = season_number
  end

  def call
    ActiveRecord::Base.transaction do
      @signed_blob_ids.each_with_index.map { |signed_id, index| file_video(signed_id, index) }
    end
  end

  private

  def file_video(signed_id, index)
    filename = @filenames[index] || "video_#{index + 1}.mp4"
    parsed = FilenameEpisodeParser.parse(filename, default_season: @season_number)
    blob = ActiveStorage::Blob.find_signed!(signed_id)

    video = @folder.videos.new(
      user: @folder.user,
      title: parsed.title.presence || filename.sub(/\.\w+$/, ""),
      season_number: parsed.season_number || @season_number,
      episode_number: parsed.episode_number || (index + 1),
      file_format: filename[/\.\w+$/]&.delete("."),
      file_size: blob.byte_size,
      status: "processing"
    )
    video.file.attach(blob)
    video.save!
    video
  end
end
