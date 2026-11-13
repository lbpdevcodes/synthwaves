class AddTypeAndYearToVideos < ActiveRecord::Migration[8.2]
  def change
    add_column :videos, :video_type, :string
    add_column :videos, :year, :integer
    add_index :videos, [:user_id, :video_type]
  end
end
