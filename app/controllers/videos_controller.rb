class VideosController < ApplicationController
  before_action :set_video, only: [:show, :edit, :update, :destroy, :stream]

  def new
    @video = Video.new
  end

  def create
    uploaded_file = params[:video_file]

    if uploaded_file.blank?
      @video = Video.new
      @video.errors.add(:file, "must be attached")
      render :new, status: :unprocessable_content
      return
    end

    file_format = uploaded_file.original_filename[/\.\w+$/]&.delete(".")

    @video = Current.user.videos.new(
      title: params[:title].presence || uploaded_file.original_filename.sub(/\.\w+$/, ""),
      description: params[:description],
      file_format: file_format,
      file_size: uploaded_file.size,
      status: "processing"
    )

    @video.file.attach(uploaded_file)

    if @video.save
      redirect_to @video, notice: "Video uploaded. Processing will begin shortly."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  def edit
  end

  def update
    if @video.update(video_params)
      redirect_to @video, notice: "Video updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @video.destroy
    redirect_to tv_path(tab: "videos"), notice: "Video deleted."
  end

  def stream
    if @video.status != "ready" || !@video.file.attached?
      head :not_found
    else
      redirect_to rails_blob_url(@video.file), allow_other_host: true
    end
  end

  private

  def set_video
    @video = Current.user.videos.find(params[:id])
  end

  def video_params
    params.require(:video).permit(:title, :description, :folder_id, :season_number, :episode_number)
  end
end
