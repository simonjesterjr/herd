# frozen_string_literal: true

module Herd
  module Db
    module Migrate
      class CreateTrackings < ActiveRecord::Migration[7.0]
        def change
          create_table :trackings do |t|
            t.references :trackable, polymorphic: true, null: false
            t.text :note, null: false
            t.jsonb :metadata, default: {}
            t.string :level, default: 'info' # info, warning, error
            t.datetime :created_at, null: false

            t.timestamps
          end

          add_index :trackings, [:trackable_type, :trackable_id]
          add_index :trackings, :level
          add_index :trackings, :created_at
        end
      end
    end
  end
end 