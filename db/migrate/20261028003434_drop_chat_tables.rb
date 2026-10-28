class DropChatTables < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key :messages, :tool_calls
    drop_table :tool_calls
    drop_table :messages
    drop_table :chats
    drop_table :models
  end

  def down
    create_table :models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.json :modalities, default: {}
      t.json :capabilities, default: []
      t.json :pricing, default: {}
      t.json :metadata, default: {}
      t.timestamps
      t.index [:provider, :model_id], unique: true
      t.index :provider
      t.index :family
    end

    create_table :chats do |t|
      t.timestamps
      t.references :model, foreign_key: true
    end

    create_table :messages do |t|
      t.string :role, null: false, index: true
      t.text :content
      t.json :content_raw
      t.text :thinking_text
      t.text :thinking_signature
      t.integer :thinking_tokens
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cached_tokens
      t.integer :cache_creation_tokens
      t.timestamps
      t.references :chat, null: false, foreign_key: true
      t.references :model, foreign_key: true
    end

    create_table :tool_calls do |t|
      t.string :tool_call_id, null: false, index: {unique: true}
      t.string :name, null: false, index: true
      t.string :thought_signature
      t.json :arguments, default: {}
      t.timestamps
      t.references :message, null: false, foreign_key: true
    end

    add_reference :messages, :tool_call, foreign_key: true
  end
end
