class FolderUploadsController < ApplicationController
  include ModalForm

  before_action :set_folder

  def new
  end

  def create
    if signed_blob_ids.empty?
      @error = "Choose at least one video file"
      return render :new, status: :unprocessable_content
    end

    videos = FolderVideoUploadService.call(folder: @folder, signed_blob_ids: signed_blob_ids,
      filenames: Array(params[:filenames]), season_number: params[:season_number].presence&.to_i)
    respond_saved @folder, notice: "Uploading #{helpers.pluralize(videos.size, "video")} to #{@folder.name}. Each appears here once it's processed."
  end

  private

  def set_folder
    @folder = Current.user.folders.find(params[:folder_id])
  end

  def signed_blob_ids
    Array(params[:signed_blob_ids]).compact_blank
  end
end
