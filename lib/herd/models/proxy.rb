# frozen_string_literal: true

module Herd
  module Models
    class Proxy < ActiveRecord::Base
      self.table_name = 'proxies'
      
      include Herd::Concerns::Trackable

      belongs_to :workflow, class_name: 'Herd::Models::Workflow'
      belongs_to :parent, class_name: 'Herd::Models::Proxy', optional: true
      has_many :children, class_name: 'Herd::Models::Proxy', foreign_key: 'parent_id'

      enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

      validates :name, presence: true
      validates :job_class, presence: true
      validates :job_id, presence: true
      validates :workflow, presence: true

      def start!
        if completed?
          errors.add(:base, "Cannot start a completed proxy")
          raise ActiveRecord::RecordInvalid.new(self)
        end
        update!(status: :running, started_at: Time.current)
      end

      def finish!
        update!(status: :completed, finished_at: Time.current)
      end

      def fail!
        update!(status: :failed, finished_at: Time.current)
      end

      def duration
        return nil unless started_at
        (finished_at || Time.current) - started_at
      end

    end
  end

end 
