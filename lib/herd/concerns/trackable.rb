# frozen_string_literal: true

module Herd
  module Concerns
    module Trackable
      extend ActiveSupport::Concern

      included do
        has_many :trackings, as: :trackable, class_name: 'Herd::Models::Tracking', dependent: :destroy
      end

      def add_note(note, level: 'info', metadata: {})
        Herd::Models::Tracking.add_note(self, note, level: level, metadata: metadata)
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