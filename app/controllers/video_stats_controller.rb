class VideoStatsController < ApplicationController
  def show
    @stats = VideoLibraryStats.new(user: Current.user)
  end
end
