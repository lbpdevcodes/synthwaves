# One user's TV → Videos grid: their collections (folders) and loose ready
# videos as a single sorted list, so both kinds share one sort and one pager.
# A search also reaches the episodes inside collections.
class VideoLibrary
  SORTS = {"added" => "Date Added", "title" => "Title"}.freeze

  Entry = Data.define(:model, :id, :title, :added_at)

  def initialize(user:, query: nil, sort: "added", direction: "desc")
    @user = user
    @query = query
    @sort = sort
    @direction = direction
  end

  def entries
    sorted = (collection_entries + video_entries).sort_by { |entry| sort_key(entry) }
    (direction == "desc") ? sorted.reverse : sorted
  end

  def records(entries)
    found = loaded(entries).index_by { |record| [record.class, record.id] }
    entries.filter_map { |entry| found[[entry.model, entry.id]] }
  end

  private

  attr_reader :user, :query, :sort, :direction

  # One query per kind, with what the cards draw.
  def loaded(entries)
    ids = entries.group_by(&:model).transform_values { |group| group.map(&:id) }
    user.folders.with_attached_cover_image.where(id: ids[Folder]) +
      user.videos.with_attached_thumbnail.includes(:folder).where(id: ids[Video])
  end

  # Each order breaks its ties with the other, so a page boundary never
  # depends on which of two equal items the sort happened to put first.
  def sort_key(entry)
    title = entry.title.downcase
    (sort == "title") ? [title, entry.added_at] : [entry.added_at, title]
  end

  def collection_entries
    newest = user.videos.in_folder.group(:folder_id).maximum(:created_at)
    user.folders.search(query).pluck(:id, :name, :created_at).map do |id, name, created_at|
      Entry.new(Folder, id, name, [created_at, newest[id]].compact.max)
    end
  end

  def video_entries
    videos.pluck(:id, :title, :created_at).map { |row| Entry.new(Video, *row) }
  end

  # A search reaches into collections; the plain grid shows their episodes
  # only through the collection's own card.
  def videos
    ready = user.videos.ready
    query.present? ? ready.search(query) : ready.standalone
  end
end
