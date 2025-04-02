# frozen_string_literal: true

module Herd
  module Concerns
    module Trackable
      extend ActiveSupport::Concern

      included do
        has_many :trackings, as: :trackable, dependent: :destroy

        scope :info_notes, -> { trackings.where(level: 'info').order(created_at: :desc) }
        scope :warning_notes, -> { trackings.where(level: 'warning').order(created_at: :desc) }
        scope :error_notes, -> { trackings.where(level: 'error').order(created_at: :desc) }
      end

      def add_note(message, level: 'info', metadata: {})
        trackings.create!(
          message: message,
          level: level,
          metadata: metadata
        )
      end

      def notes
        trackings.recent
      end

      def info_notes
        trackings.info.recent
      end

      def warning_notes
        trackings.warning.recent
      end

      def error_notes
        trackings.error.recent
      end
    end
  end
end 