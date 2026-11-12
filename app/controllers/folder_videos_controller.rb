# Moves several of the owner's videos into a folder at once, picked from a
# checklist in the modal.
class FolderVideosController < ApplicationController
  include ModalForm

  before_action :set_folder

  def new
  end

  def create
    if video_ids.empty?
      @error = "Pick at least one video"
      return render :new, status: :unprocessable_content
    end

    videos = @folder.add_videos(Current.user.videos.find(video_ids))
    respond_saved @folder, notice: "Added #{helpers.pluralize(videos.size, "video")} to #{@folder.name}."
  end

  private

  def set_folder
    @folder = Current.user.folders.find(params[:folder_id])
  end

  def video_ids
    Array(params[:video_ids]).compact_blank
  end
end
