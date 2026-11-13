class CreateDeviceSignIns < ActiveRecord::Migration[8.2]
  def change
    create_table :device_sign_ins do |t|
      t.string :code, null: false, index: {unique: true}
      t.string :secret_digest, null: false, index: {unique: true}
      t.string :device_name, null: false
      t.references :user, foreign_key: true
      t.datetime :expires_at, null: false, index: true

      t.timestamps
    end
  end
end
