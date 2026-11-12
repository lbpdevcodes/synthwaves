class API::Subsonic::BaseController < ActionController::API
  include SubsonicAuthentication
  include SubsonicResponseFormatting

  private

  def render_missing_param(name)
    render_subsonic_error(10, "Required parameter is missing: #{name}")
  end

  # Every value of a repeated parameter. Subsonic clients repeat a key
  # without brackets (videoId=1&videoId=2) and Rails keeps only the last,
  # so this reads the query string and a urlencoded form body itself.
  # The bracketed form (videoId[]=1) works too.
  def param_values(name)
    pairs = Rack::Utils.parse_query([request.query_string, urlencoded_body].compact_blank.join("&"))
    Array(pairs[name.to_s]) + Array(pairs["#{name}[]"])
  end

  def urlencoded_body
    request.raw_post if request.content_mime_type == Mime[:url_encoded_form]
  end

  # Albums with nothing to play are hidden unless the client asks for them.
  # The native apps do, so a newly created album doesn't vanish.
  def listable(albums)
    (params[:includeEmpty] == "true") ? albums : albums.with_streamable_tracks
  end

  # Redirects to an attached image, resized to a square when the client
  # asks for a size.
  def redirect_to_image(image)
    size = params[:size].to_i
    url = size.positive? ? rails_representation_url(image.variant(resize_to_fill: [size, size])) : rails_blob_url(image)
    redirect_to url, allow_other_host: true
  end

  def rails_blob_url(blob)
    Rails.application.routes.url_helpers.rails_blob_url(
      blob, host: request.host_with_port, protocol: request.scheme
    )
  end

  def rails_representation_url(variant)
    Rails.application.routes.url_helpers.rails_representation_url(
      variant, host: request.host_with_port, protocol: request.scheme
    )
  end
end
