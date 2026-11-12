# Folders inside folders. Keeps the tree whole: a parent comes from the same
# library and never from below the folder itself, and deleting a folder moves
# what's in it one level up.
module Folder::Nesting
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: "Folder", optional: true
    has_many :children, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify

    validate :parent_in_same_library, :parent_outside_own_subtree, if: :will_save_change_to_parent_id?

    # Prepended to run before the nullify callbacks; skipped when the whole
    # account goes, since its folders all go with it.
    before_destroy :move_contents_up, prepend: true, unless: :destroyed_by_association
  end

  protected

  # This folder's id and every saved folder's below it. Read from the
  # database, so an unsaved parent change can't send it round in a loop.
  def subtree_ids
    [id, *Folder.where(parent_id: id).flat_map { |child| child.subtree_ids }]
  end

  private

  def parent_in_same_library
    errors.add(:parent, "must be one of your folders") if parent && parent.user_id != user_id
  end

  def parent_outside_own_subtree
    return unless persisted? && parent_id && subtree_ids.include?(parent_id)

    errors.add(:base, "A folder can't go inside itself or one of its own subfolders")
  end

  def move_contents_up
    clash = clashing_name
    refuse_deletion(clash) if clash
    children.update_all(parent_id: parent_id)
    videos.update_all(folder_id: parent_id)
  end

  # The first subfolder name that would meet its twin one level up.
  def clashing_name
    children.pluck(:name).intersection(siblings.pluck(:name)).first
  end

  def siblings
    Folder.where(user_id: user_id, parent_id: parent_id).where.not(id: id)
  end

  def refuse_deletion(name)
    errors.add(:base, "Can't delete #{self.name}: #{parent&.name || "Videos"} already has a folder named #{name}.")
    throw :abort
  end
end
