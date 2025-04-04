class CreateWorkflows < ActiveRecord::Migration[7.1]
  def change
    create_table :workflows, id: false do |t|
      t.uuid :id, default: -> { "gen_random_uuid()" }, null: false, primary_key: true
      t.string :name, null: false
      t.integer :status, default: 'pending'
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :arguments, default: {}

      t.timestamps
    end

    add_index :workflows, :status
    add_index :workflows, :started_at
    add_index :workflows, :finished_at
  end
end 