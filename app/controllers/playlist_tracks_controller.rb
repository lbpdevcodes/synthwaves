class PlaylistTracksController < ApplicationController
  include InPlaceRefresh

  before_action :set_playlist

  def create
    respond_in_place added_notice(add_tracks), fallback: @playlist
  end

  # A drag sends the position the track was dropped on; the Move up and
  # Move down buttons send a direction.
  def update
    playlist_track = @playlist.playlist_tracks.find(params[:id])
    if params[:direction].present?
      @playlist.step_track!(playlist_track, params[:direction])
    else
      @playlist.move_track!(playlist_track, to: params[:position])
    end
    respond_in_place nil, fallback: @playlist
  end

  def destroy
    @playlist.remove_track(@playlist.playlist_tracks.find(params[:id]))
    respond_in_place "Removed from #{@playlist.name}.", fallback: @playlist
  end

  private

  def add_tracks
    if params[:track_ids].present?
      add_multiple_tracks
    elsif params[:album_id].present?
      add_album_tracks
    else
      add_single_track ? 1 : 0
    end
  end

  def added_notice(count)
    return "Already in #{@playlist.name}." if count.zero?

    (count == 1) ? "Added to #{@playlist.name}." : "Added #{count} tracks to #{@playlist.name}."
  end

  def add_multiple_tracks
    tracks = Current.user.tracks.where(id: params[:track_ids])
    ordered = params[:track_ids].map(&:to_i).filter_map { |id| tracks.find { |t| t.id == id } }
    @playlist.add_tracks(ordered)
  end

  def add_single_track
    track = Current.user.tracks.find(params[:track_id])
    @playlist.add_track(track)
  end

  def add_album_tracks
    album = Current.user.albums.find(params[:album_id])
    @playlist.add_tracks(album.tracks.order(:disc_number, :track_number))
  end

  def set_playlist
    @playlist = Current.user.playlists.find(params[:playlist_id])
  end
end
