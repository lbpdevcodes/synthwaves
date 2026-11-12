# Moves one video into a folder, or out of the one it is in, from wherever
# the user sees the video. The page refreshes in place.
class VideoFoldersController < ApplicationController
  include InPlaceRefresh

  before_action :set_video

  def update
    folder = Current.user.folders.find(params[:folder_id])
    folder.add_videos([@video])
    respond_in_place %(Moved "#{@video.title}" to #{folder.name}.), fallback: @video
  end

  def destroy
    folder = Current.user.folders.find(@video.folder_id)
    folder.remove_videos([@video])
    respond_in_place %(Removed "#{@video.title}" from #{folder.name}.), fallback: @video
  end

  private

  def set_video
    @video = Current.user.videos.find(params[:video_id])
  end
end
