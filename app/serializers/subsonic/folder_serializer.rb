module Subsonic
  class FolderSerializer
    # One folder in a list. video_count is the number of its ready videos,
    # counted by the caller so a list of folders is counted in one query.
    def self.to_entry(folder, video_count:)
      {
        id: folder.id.to_s,
        name: folder.name,
        description: folder.description.presence,
        videoCount: video_count,
        created: folder.created_at.iso8601
      }.compact
    end

    # One folder with its ready videos, in episode order.
    def self.to_detail(folder)
      videos = folder.videos.ready.ordered.includes(:folder)
      to_entry(folder, video_count: videos.size).merge(video: videos.map { |video| VideoSerializer.to_entry(video) })
    end
  end
end
