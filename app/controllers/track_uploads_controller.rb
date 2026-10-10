class TrackUploadsController < ApplicationController
  include ModalForm

  def new
    @upload = TrackUpload.new(album: album, artist: artist)
  end

  def create
    @upload = TrackUpload.new(album: album, artist: artist, album_title: params[:album_title], signed_blob_ids: params[:signed_blob_ids])
    if @upload.save
      respond_created @upload.destination, notice: "#{helpers.pluralize(@upload.tracks.size, "track")} added to #{@upload.destination.title}."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def album
    Current.user.albums.find(params[:album_id]) if params[:album_id].present?
  end

  def artist
    Current.user.artists.find(params[:artist_id]) if params[:artist_id].present?
  end
end
