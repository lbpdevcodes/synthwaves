# The self-hosted Icecast + Liquidsoap radio stack was removed in #76; these
# tables and any station image attachments were left behind.
class DropRadioStationTables < ActiveRecord::Migration[8.2]
  def up
    execute "DELETE FROM active_storage_attachments WHERE record_type = 'RadioStation'"
    drop_table :radio_queue_tracks
    drop_table :radio_stations
  end

  def down
    create_table :radio_stations do |t|
      t.references :playlist, null: false, foreign_key: true, index: {unique: true}
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "stopped", index: true
      t.string :mount_point, null: false, index: {unique: true}
      t.string :playback_mode, null: false, default: "shuffle"
      t.integer :bitrate, null: false, default: 192
      t.boolean :crossfade, null: false, default: true
      t.float :crossfade_duration, null: false, default: 3.0
      t.references :current_track, foreign_key: {to_table: :tracks}
      t.integer :listener_count, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :last_track_at
      t.timestamps
      t.references :queued_track, foreign_key: {to_table: :tracks}
      t.float :favorites_weight, null: false, default: 2.0
    end

    create_table :radio_queue_tracks do |t|
      t.references :radio_station, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.integer :position, null: false
      t.datetime :played_at
      t.timestamps
      t.index [:radio_station_id, :position], unique: true
      t.index [:radio_station_id, :played_at]
    end
  end
end
