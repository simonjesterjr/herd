# frozen_string_literal: true

module Herd
  module Db
    module Migrate
      class CreateProxies < ActiveRecord::Migration[7.0]
        def change
          create_table :proxies do |t|
            t.references :workflow, null: false, foreign_key: { to_table: :workflows }
            t.references :parent, foreign_key: { to_table: :proxies }
            t.integer :status, null: false, default: 0

            t.timestamps
          end

          add_index :proxies, :status
          add_index :proxies, [:workflow_id, :parent_id]
        end
      end
    end
  end
end 