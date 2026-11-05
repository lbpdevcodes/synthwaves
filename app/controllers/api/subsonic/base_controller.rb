class API::Subsonic::BaseController < ActionController::API
  include SubsonicAuthentication
  include SubsonicResponseFormatting

  private

  # Albums with nothing to play are hidden unless the client asks for them.
  # The native apps do, so a newly created album doesn't vanish.
  def listable(albums)
    (params[:includeEmpty] == "true") ? albums : albums.with_streamable_tracks
  end
end
