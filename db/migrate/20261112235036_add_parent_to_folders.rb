class AddParentToFolders < ActiveRecord::Migration[8.2]
  def change
    add_reference :folders, :parent, foreign_key: {to_table: :folders}
    remove_index :folders, [:user_id, :name], unique: true
    add_index :folders, [:user_id, :parent_id, :name], unique: true
  end
end
