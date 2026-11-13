# One user's TV → Videos grid: their collections (folders) and loose ready
# videos as a single sorted list, so both kinds share one sort and one pager.
# A search also reaches the episodes inside collections. A type or genre
# shows the videos that match, and the collections holding any.
class VideoLibrary
  SORTS = {"added" => "Date Added", "title" => "Title", "year" => "Year"}.freeze

  Entry = Data.define(:model, :id, :title, :added_at, :year)

  def initialize(user:, filter: VideoFilter.new, sort: "added", direction: "desc")
    @user = user
    @filter = filter
    @sort = sort
    @direction = direction
  end

  # By year, what has none comes last either way round, by title.
  def entries
    dated, undated = (collection_entries + video_entries).partition { |entry| sort != "year" || entry.year }
    ordered(dated) + undated.sort_by { |entry| title_key(entry) }
  end

  def records(entries)
    found = loaded(entries).index_by { |record| [record.class, record.id] }
    entries.filter_map { |entry| found[[entry.model, entry.id]] }
  end

  private

  attr_reader :user, :filter, :sort, :direction

  delegate :query, to: :filter

  # One query per kind, with what the cards draw.
  def loaded(entries)
    ids = entries.group_by(&:model).transform_values { |group| group.map(&:id) }
    user.folders.with_attached_cover_image.where(id: ids[Folder]) +
      user.videos.with_attached_thumbnail.with_attached_cover_image.includes(:folder).where(id: ids[Video])
  end

  def ordered(entries)
    sorted = entries.sort_by { |entry| sort_key(entry) }
    (direction == "desc") ? sorted.reverse : sorted
  end

  # Each order breaks its ties with another, so a page boundary never
  # depends on which of two equal items the sort happened to put first.
  def sort_key(entry)
    case sort
    when "title" then title_key(entry)
    when "year" then [entry.year, entry.title.downcase]
    else [entry.added_at, entry.title.downcase]
    end
  end

  def title_key(entry) = [entry.title.downcase, entry.added_at]

  # A collection counts from its own videos: its newest, and its latest year.
  def collection_entries
    own = user.videos.in_folder.group(:folder_id)
    newest, latest_year = own.maximum(:created_at), own.maximum(:year)
    folders.pluck(:id, :name, :created_at).map do |id, name, created_at|
      Entry.new(Folder, id, name, [created_at, newest[id]].compact.max, latest_year[id])
    end
  end

  def folders
    browsed = user.folders.browse(query)
    filter.narrows? ? browsed.where(id: folders_holding_matches) : browsed
  end

  # Each folder a matching video sits in, and every folder above it.
  def folders_holding_matches
    parents = user.folders.pluck(:id, :parent_id).to_h
    filter.apply(user.videos.ready).distinct.pluck(:folder_id).flat_map { |id| lineage(id, parents) }
  end

  def lineage(id, parents) = id ? [id, *lineage(parents[id], parents)] : []

  def video_entries
    videos.pluck(:id, :title, :created_at, :year).map { |row| Entry.new(Video, *row) }
  end

  # A search reaches into collections; the plain grid shows their episodes
  # only through the collection's own card.
  def videos
    ready = filter.apply(user.videos.ready)
    query.present? ? ready.search(query) : ready.standalone
  end
end
