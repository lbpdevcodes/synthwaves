class TvController < ApplicationController
  TABS = %w[videos podcasts].freeze

  def show
    @available_tabs = TABS
    @tab = params[:tab].presence_in(TABS) || "videos"
    (@tab == "videos") ? load_videos : load_podcasts
  end

  private

  def load_videos
    @filter = VideoFilter.new(query: params[:q], type: params[:type], genre: params[:genre])
    @genres = Current.user.videos.genre_names
    @sort = params[:sort].presence_in(VideoLibrary::SORTS.keys) || "added"
    @direction = sort_direction(default: "desc")
    load_library VideoLibrary.new(user: Current.user, filter: @filter, sort: @sort, direction: @direction)
  end

  # Pagy slices an array, which gives nil for a page past the end.
  def load_library(library)
    @pagy, entries = pagy(library.entries)
    @items = library.records(entries.to_a)
  end

  def load_podcasts
    @query = params[:q]
    scope = Current.user.artists.podcast.includes(albums: {cover_image_attachment: :blob})
      .search(@query)
      .order(:name)
    @pagy, @podcasts = pagy(:offset, scope)
  end
end
