class AddLoudnessToTracks < ActiveRecord::Migration[8.2]
  def change
    add_column :tracks, :loudness_lufs, :float
    add_column :tracks, :loudness_gain_db, :float
  end
end
