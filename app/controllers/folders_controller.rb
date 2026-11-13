class FoldersController < ApplicationController
  include ModalForm
  include DestroyRedirect

  before_action :set_folder, only: [:show, :edit, :update, :destroy]

  def new
    @folder = Current.user.folders.new(parent: Current.user.folders.find_by(id: params[:parent_id]))
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
    @subfolders = @folder.children.order(:name)
    @processing_count = @folder.videos.where(status: "processing").count
    @failed_count = @folder.videos.where(status: "failed").count
  end

  def edit
  end

  def update
    if @folder.update(folder_params)
      respond_saved @folder, notice: "Collection updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    notice, home = deleted_notice, helpers.folder_parent_path(@folder)
    return redirect_to(@folder, alert: @folder.errors.full_messages.to_sentence) unless @folder.destroy

    redirect_after_destroy folder_path(@folder), parent: home, notice: notice
  end

  private

  def save_with(videos)
    Folder.transaction { @folder.save && @folder.add_videos(videos) }
  end

  # A folder made from a video's menu (it arrives with video_ids) keeps the
  # user on that page; one made from the New Collection form opens.
  def respond_to_create(videos)
    if videos.any?
      respond_in_place "Created #{@folder.name} with #{helpers.pluralize(videos.size, "video")}.", fallback: @folder
    else
      respond_created @folder, notice: "Created #{@folder.name}."
    end
  end

  def respond_to_invalid(videos)
    if videos.any?
      respond_in_place "Couldn't create the collection: #{@folder.errors.full_messages.to_sentence}.", fallback: tv_path(tab: "videos")
    else
      render :new, status: :unprocessable_content
    end
  end

  def deleted_notice
    contents = helpers.folder_contents(@folder)
    return "Deleted #{@folder.name}." if contents.empty?

    "Deleted #{@folder.name}. #{contents} moved #{@folder.parent ? "to #{@folder.parent.name}" : "back to Videos"}."
  end

  def set_folder
    @folder = Current.user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :cover_image, :parent_id)
  end
end
