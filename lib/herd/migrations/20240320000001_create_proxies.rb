class CreateProxies < ActiveRecord::Migration[7.1]
  def change
    create_table :proxies do |t|
      t.references :workflow, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :proxies }, null: true
      t.string :name, null: false
      t.integer :status, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :metadata, default: {}
      t.string :job_class, null: false
      t.string :job_id, null: false

      t.timestamps
    end

    add_index :proxies, :status
    add_index :proxies, :started_at
    add_index :proxies, :finished_at
    add_index :proxies, :job_id
  end
end 