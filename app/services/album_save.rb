# Saves the album form. The artist arrives as a typed name: it joins the
# owner's artist of that name, ignoring case, or creates one. A blank name
# keeps the current artist. A failed save rolls back any artist it created.
class AlbumSave
  def self.call(album, attributes)
    new(album, attributes).call
  end

  def initialize(album, attributes)
    @album = album
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    Album.transaction do
      assign
      album.save or raise ActiveRecord::Rollback
    end.present?
  end

  private

  attr_reader :album, :attributes

  def assign
    album.assign_attributes(attributes.except(:artist_name))
    album.artist = Artist.find_or_create_named!(album.user, artist_name) if artist_name.present?
  end

  def artist_name
    attributes[:artist_name].to_s.strip
  end
end
