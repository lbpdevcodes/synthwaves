class CreateVideoSubtitles < ActiveRecord::Migration[8.2]
  def change
    create_table :video_subtitles do |t|
      t.references :video, null: false, foreign_key: true
      t.string :label, null: false
      t.string :language
      t.string :kind, null: false, default: "subtitles"
      t.text :vtt, null: false
      t.timestamps
    end
    add_index :video_subtitles, [:video_id, :label], unique: true
  end
end
