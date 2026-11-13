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
    @sort = params[:sort].presence_in(VideoLibrary::SORTS.keys) || "added"
    @direction = sort_direction(default: "desc")
    load_library VideoLibrary.new(user: Current.user, filter: VideoFilter.new(query: @query), sort: @sort, direction: @direction)
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
