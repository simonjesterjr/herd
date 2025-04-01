# frozen_string_literal: true

module Herd
  module Db
    module Migrate
      class CreateWorkflows < ActiveRecord::Migration[7.0]
        def change
          create_table :workflows do |t|
            t.string :name, null: false
            t.integer :status, null: false, default: 0
            t.jsonb :arguments
            t.boolean :stopped, default: false
            t.datetime :started_at
            t.datetime :finished_at

            t.timestamps
          end

          add_index :workflows, :status
          add_index :workflows, :name
        end
      end
    end
  end
end 