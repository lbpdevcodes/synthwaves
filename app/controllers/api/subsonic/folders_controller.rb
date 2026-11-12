class API::Subsonic::FoldersController < API::Subsonic::BaseController
  def get_folders
    folders = current_user.folders.includes(:videos)
    folder_entries = folders.map do |folder|
      {
        id: folder.id.to_s,
        name: folder.name,
        videoCount: folder.videos.ready.size
      }
    end

    render_subsonic(folders: {folder: folder_entries})
  end

  def get_folder
    folder = current_user.folders.find(params[:id])
    videos = folder.videos.ready.ordered

    render_subsonic(
      folder: {
        id: folder.id.to_s,
        name: folder.name,
        video: videos.map { |v| video_to_entry(v) }
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Folder not found")
  end
end
