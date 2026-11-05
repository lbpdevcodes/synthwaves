class API::V1::AlbumCoversController < API::V1::BaseController
  IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  before_action :set_album

  def update
    return render_error("cover_image must be a JPEG, PNG, GIF, or WebP image") unless image_upload?

    @album.cover_image.attach(cover_image)
    render_album
  end

  def destroy
    @album.cover_image.purge
    render_album
  end

  private

  def set_album
    @album = current_user.albums.find(params[:album_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def cover_image
    params[:cover_image]
  end

  # Judged from the file's bytes, because the upload's content type is
  # whatever the client says it is.
  def image_upload?
    cover_image.respond_to?(:path) && IMAGE_TYPES.include?(Marcel::MimeType.for(Pathname.new(cover_image.path)))
  end

  def render_album
    render json: API::V1::AlbumSerializer.render_as_hash(@album, view: :full)
  end
end
