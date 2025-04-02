class CreateTrackings < ActiveRecord::Migration[7.1]
  def change
    create_table :trackings do |t|
      t.references :trackable, polymorphic: true, null: false
      t.string :level, null: false, default: 'info'
      t.text :message, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :trackings, [:trackable_type, :trackable_id]
    add_index :trackings, :level
    add_index :trackings, :created_at
  end
end 