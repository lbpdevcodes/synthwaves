class ArtistResource < Madmin::Resource
  attribute :id, form: false
  attribute :name
  attribute :user
  attribute :category
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.display_name(record) = record.name
end
