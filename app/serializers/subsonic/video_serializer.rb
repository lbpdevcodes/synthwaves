module Subsonic
  class VideoSerializer
    def self.to_entry(video)
      {
        id: video.id.to_s,
        title: video.title,
        description: video.description,
        duration: video.duration&.to_i,
        width: video.width,
        height: video.height,
        size: video.file_size,
        contentType: "video/mp4",
        fileFormat: video.file_format,
        folderId: video.folder_id&.to_s,
        folderName: video.folder&.name,
        episodeNumber: video.episode_number,
        seasonNumber: video.season_number,
        created: video.created_at.iso8601
      }.compact
    end

    # One video with its subtitle tracks. Lists leave the tracks out, so a
    # library of videos isn't read with every track's WebVTT.
    def self.to_detail(video)
      to_entry(video).merge(subtitles: subtitle_entries(video))
    end

    # Leaves out each track's WebVTT text, which getVideoSubtitle serves.
    def self.subtitle_entries(video)
      video.subtitles.select(:id, :label, :language, :kind).map { |subtitle| subtitle_entry(subtitle) }
    end

    def self.subtitle_entry(subtitle)
      {id: subtitle.id.to_s, label: subtitle.label, language: subtitle.language, kind: subtitle.kind}.compact
    end
  end
end
