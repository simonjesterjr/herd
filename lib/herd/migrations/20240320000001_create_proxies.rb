class CreateProxies < ActiveRecord::Migration[7.1]
  def change
    create_table :proxies, id: false do |t|
      t.uuid :id, default: -> { "gen_random_uuid()" }, null: false, primary_key: true
      t.uuid :workflow_id, null: false
      t.uuid :parent_id
      t.string :name
      t.integer :status, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :metadata, default: {}
      t.string :job_class
      t.string :job_id
      t.jsonb :arguments, default: {}

      t.timestamps
    end

    add_index :proxies, :status
    add_index :proxies, :started_at
    add_index :proxies, :finished_at
    add_index :proxies, :job_id
    add_index :proxies, :workflow_id
    add_index :proxies, :parent_id
    
    add_foreign_key :proxies, :workflows, column: :workflow_id
    add_foreign_key :proxies, :proxies, column: :parent_id
  end
end 