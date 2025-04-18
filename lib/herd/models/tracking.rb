# frozen_string_literal: true

module Herd
  module Models
    class Tracking < ActiveRecord::Base
      belongs_to :trackable, polymorphic: true

      validates :message, presence: true
      validates :level, inclusion: { in: %w[info warning error] }

      scope :info, -> { where(level: 'info') }
      scope :warning, -> { where(level: 'warning') }
      scope :error, -> { where(level: 'error') }
      scope :recent, -> { order(created_at: :desc) }
      scope :for_trackable, ->(trackable) { where(trackable: trackable) }

      def self.add_note(trackable, message, level: 'info', metadata: {})
        create!(
          trackable: trackable,
          message: message,
          level: level,
          metadata: metadata,
          created_at: Time.current
        )
      end
    end
  end
end 