class FoldersController < ApplicationController
  include ModalForm
  include DestroyRedirect

  before_action :set_folder, only: [:show, :edit, :update, :destroy]

  def new
    @folder = Folder.new
  end

  def create
    @folder = Current.user.folders.new(folder_params)
    videos = Current.user.videos.find(Array(params[:video_ids]))
    save_with(videos) ? respond_to_create(videos) : respond_to_invalid(videos)
  end

  def show
    @query = params[:q]
    @season = params[:season]
    @sort = sort_column(Video, default: "episode_number")
    @direction = sort_direction

    @available_seasons = @folder.videos.ready.where.not(season_number: nil).distinct.pluck(:season_number).sort
    @season_counts = @folder.videos.ready.where.not(season_number: nil).group(:season_number).count

    scope = @folder.videos.ready.search(@query)
    scope = scope.where(season_number: @season) if @season.present?

    scope = if @sort == "episode_number"
      scope.order(season_number: @direction, episode_number: @direction)
    else
      scope.order(@sort => @direction)
    end

    @pagy, @videos = pagy(:offset, scope, limit: 24)
    @processing_count = @folder.videos.where(status: "processing").count
    @failed_count = @folder.videos.where(status: "failed").count
  end

  def edit
  end

  def update
    if @folder.update(folder_params)
      respond_saved @folder, notice: "Folder updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    notice = deleted_notice
    @folder.destroy
    redirect_after_destroy folder_path(@folder), parent: tv_path(tab: "videos"), notice: notice
  end

  private

  def save_with(videos)
    Folder.transaction { @folder.save && @folder.add_videos(videos) }
  end

  # A folder made from a video's menu (it arrives with video_ids) keeps the
  # user on that page; one made from the New Folder form opens.
  def respond_to_create(videos)
    if videos.any?
      respond_in_place "Created #{@folder.name} with #{helpers.pluralize(videos.size, "video")}.", fallback: @folder
    else
      respond_created @folder, notice: "Created #{@folder.name}."
    end
  end

  def respond_to_invalid(videos)
    if videos.any?
      respond_in_place "Couldn't create the folder: #{@folder.errors.full_messages.to_sentence}.", fallback: tv_path(tab: "videos")
    else
      render :new, status: :unprocessable_content
    end
  end

  def deleted_notice
    moved = @folder.videos.count
    return "Deleted #{@folder.name}." if moved.zero?

    "Deleted #{@folder.name}. #{helpers.pluralize(moved, "video")} moved back to Videos."
  end

  def set_folder
    @folder = Current.user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :cover_image)
  end
end
