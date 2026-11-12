# One user's folders arranged as a tree, for the pickers that list them:
# parents first, siblings by name, each labelled with its path.
class FolderTree
  include Enumerable

  SEPARATOR = " › "

  def initialize(folders)
    @folders = folders
  end

  def each(&)
    ordered.each(&)
  end

  def label(folder)
    path(folder).map(&:name).join(SEPARATOR)
  end

  # Where the folder could move: anywhere but into itself or below itself.
  def possible_parents_for(folder)
    reject { |candidate| path(candidate).include?(folder) }
  end

  private

  attr_reader :folders

  def ordered
    @ordered ||= branch(nil)
  end

  def branch(parent_id)
    children_of.fetch(parent_id, []).sort_by(&:name).flat_map { |folder| [folder, *branch(folder.id)] }
  end

  def path(folder)
    parent = by_id[folder.parent_id]
    parent ? [*path(parent), folder] : [folder]
  end

  def children_of
    @children_of ||= folders.group_by(&:parent_id)
  end

  def by_id
    @by_id ||= folders.index_by(&:id)
  end
end
