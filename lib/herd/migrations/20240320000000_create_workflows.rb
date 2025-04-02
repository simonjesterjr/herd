class CreateWorkflows < ActiveRecord::Migration[7.1]
  def change
    create_table :workflows do |t|
      t.string :name, null: false
      t.integer :status, default: 'pending'
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :arguments, default: {}
      t.boolean :stopped, default: false

      t.timestamps
    end

    add_index :workflows, :status
    add_index :workflows, :started_at
    add_index :workflows, :finished_at
  end
end 