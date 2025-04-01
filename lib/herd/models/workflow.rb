# frozen_string_literal: true

module Herd
  module Models
    class Workflow < ActiveRecord::Base
      include Herd::Concerns::Trackable

      has_many :proxies, class_name: 'Herd::Models::Proxy', dependent: :destroy

      enum status: {
        running: 0,
        finished: 1,
        failed: 2,
        stopped: 3
      }

      validates :name, presence: true
      validates :status, presence: true

      before_validation :set_default_status, on: :create

      def mark_as_started
        update!(status: :running, started_at: Time.current)
        add_note("Workflow started", level: 'info')
      end

      def mark_as_finished
        update!(status: :finished, finished_at: Time.current)
        add_note("Workflow finished successfully", level: 'info')
      end

      def mark_as_failed
        update!(status: :failed, finished_at: Time.current)
        add_note("Workflow failed", level: 'error')
      end

      def mark_as_stopped
        update!(status: :stopped)
        add_note("Workflow stopped", level: 'warning')
      end

      private

      def set_default_status
        self.status ||= :running
      end
    end
  end
end 