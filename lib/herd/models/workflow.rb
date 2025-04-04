# frozen_string_literal: true

module Herd
  module Models
    class Workflow < ActiveRecord::Base
      include Herd::Concerns::Trackable

      has_many :proxies, class_name: 'Herd::Models::Proxy', dependent: :destroy

      enum :status, { pending: 0, running: 1, completed: 2, failed: 3, stopped: 4 }, default: :pending

      validates :name, presence: true

      def start!
        if completed?
          errors.add(:base, "Cannot start a completed proxy")
          raise ActiveRecord::RecordInvalid.new(self)
        end
        update!(status: :running, started_at: Time.current)
      end

      def stop!
        update!( status: :stopped, finished_at: Time.current )
        add_note("Workflow stopped", level: 'warning')
      end

      def finish!
        update!(status: :completed, finished_at: Time.current)
        add_note("Workflow finished successfully", level: 'info')
      end

      def fail!
        update!(status: :failed, finished_at: Time.current)
        add_note("Workflow failed", level: 'error')
      end

      def duration
        return nil unless started_at
        (finished_at || Time.current) - started_at
      end

    end
  end

end 
