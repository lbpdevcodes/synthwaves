class AddAnimatedToVideos < ActiveRecord::Migration[8.2]
  def change
    add_column :videos, :animated, :boolean, default: false, null: false
  end
end
