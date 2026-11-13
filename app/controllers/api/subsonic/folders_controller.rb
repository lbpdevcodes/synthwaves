class API::Subsonic::FoldersController < API::Subsonic::BaseController
  rescue_from ActiveRecord::RecordNotFound do |error|
    render_subsonic_error(70, "#{error.model} not found")
  end

  rescue_from ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed do |error|
    render_subsonic_error(0, error.record.errors.full_messages.to_sentence)
  end

  def get_folders
    counts = current_user.videos.ready.group(:folder_id).count
    entries = current_user.folders.order(:name).map do |folder|
      Subsonic::FolderSerializer.to_entry(folder, video_count: counts.fetch(folder.id, 0))
    end

    render_subsonic(folders: {folder: entries})
  end

  def get_folder
    render_folder(current_user.folders.find(params[:id]))
  end

  def create_folder
    return render_missing_param(:name) if params[:name].blank?

    folder = Folder.transaction do
      current_user.folders.create!(name: params[:name], description: params[:description], parent: requested_parent).tap do |created|
        created.add_videos(find_videos(:videoId))
      end
    end
    render_folder(folder)
  end

  def update_folder
    return render_missing_param(:id) if params[:id].blank?

    folder = current_user.folders.find(params[:id])
    Folder.transaction do
      folder.update!(folder_changes)
      folder.add_videos(find_videos(:videoIdToAdd))
      folder.remove_videos(find_videos(:videoIdToRemove))
    end
    render_folder(folder)
  end

  def delete_folder
    return render_missing_param(:id) if params[:id].blank?

    current_user.folders.find(params[:id]).destroy!
    render_subsonic
  end

  def get_folder_cover
    cover = current_user.folders.find_by(id: params[:id])&.cover
    cover ? redirect_to_image(cover) : head(:not_found)
  end

  private

  def find_videos(param)
    current_user.videos.find(param_values(param))
  end

  # The folder parentId names, or nil, for the top level, when it is blank.
  def requested_parent
    current_user.folders.find(params[:parentId]) if params[:parentId].present?
  end

  # What updateFolder changes: only the fields the client sent.
  def folder_changes
    changes = params.slice(:name, :description).permit(:name, :description).to_h
    params.key?(:parentId) ? changes.merge(parent: requested_parent) : changes
  end

  def render_folder(folder)
    render_subsonic(folder: Subsonic::FolderSerializer.to_detail(folder))
  end
end
