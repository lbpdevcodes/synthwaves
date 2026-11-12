# Live TV is gone: IPTV channels, their guide and the recordings made from them.
# The recordings' MP4s leave storage too. Favorites point at a channel by type
# and id, so they go first; attachments are deleted by SQL because the Recording
# class no longer exists to destroy them through.
class RemoveLiveTv < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM favorites WHERE favorable_type = 'IPTVChannel'"
    purge_recording_files
    drop_table :user_recordings
    drop_table :recordings
    drop_table :epg_programmes
    drop_table :iptv_channels
    drop_table :iptv_categories
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def purge_recording_files
    attachments = ActiveStorage::Attachment.where(record_type: "Recording")
    blob_ids = attachments.pluck(:blob_id)
    attachments.delete_all
    ActiveStorage::Blob.where(id: blob_ids).find_each(&:purge_later)
  end
end
