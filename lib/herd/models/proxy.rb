# frozen_string_literal: true

module Herd
  module Models
    class Proxy < ActiveRecord::Base
      include Herd::Concerns::Trackable

      belongs_to :workflow, class_name: 'Herd::Models::Workflow'
      belongs_to :parent, class_name: 'Herd::Models::Proxy', optional: true
      has_many :children, class_name: 'Herd::Models::Proxy', foreign_key: 'parent_id'

      enum status: {
        partitioned: 0,
        in_process: 1,
        done: 2,
        completed: 3,
        errored: 4
      }

      validates :status, presence: true

      before_validation :set_default_status, on: :create

      def partitioned!
        update!(status: :partitioned)
        add_note("Job partitioned", level: 'info')
      end

      def in_process!
        update!(status: :in_process)
        add_note("Job started processing", level: 'info')
      end

      def done!
        update!(status: :done)
        add_note("Job completed", level: 'info')
      end

      def completed!
        update!(status: :completed)
        add_note("Job fully completed", level: 'info')
      end

      def errored!
        update!(status: :errored)
        add_note("Job encountered an error", level: 'error')
      end

      private

      def set_default_status
        self.status ||= :partitioned
      end
    end
  end
end 