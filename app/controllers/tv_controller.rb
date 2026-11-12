class TvController < ApplicationController
  TABS = %w[videos podcasts].freeze

  def show
    @available_tabs = TABS
    @tab = params[:tab].presence_in(TABS) || "videos"
    (@tab == "videos") ? load_videos : load_podcasts
  end

  private

  def load_videos
    @query = params[:q]
    @folders = Current.user.folders.search(@query).order(:name)
    scope = Current.user.videos.ready.standalone.search(@query).order(created_at: :desc)
    @pagy, @videos = pagy(scope)
  end

  def load_podcasts
    @query = params[:q]
    scope = Current.user.artists.podcast.includes(albums: {cover_image_attachment: :blob})
      .search(@query)
      .order(:name)
    @pagy, @podcasts = pagy(:offset, scope)
  end
end
