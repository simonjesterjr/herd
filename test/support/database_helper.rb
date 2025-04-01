# frozen_string_literal: true

module Herd
  module Test
    module DatabaseHelper
      def mock_workflow_model
        @mock_workflow_model ||= Minitest::Mock.new.tap do |mock|
          mock.expect :update!, true
          mock.expect :destroy, true
          mock.expect :add_note, true, [String, Hash]
          mock.expect :notes, []
          mock.expect :info_notes, []
          mock.expect :warning_notes, []
          mock.expect :error_notes, []
          mock.expect :mark_as_started, true
          mock.expect :mark_as_stopped, true
          mock.expect :mark_as_finished, true
          mock.expect :mark_as_failed, true
          mock.expect :finished?, false
          mock.expect :failed?, false
          mock.expect :stopped?, false
          mock.expect :started_at, nil
          mock.expect :finished_at, nil
        end
      end

      def mock_proxy_model
        @mock_proxy_model ||= Minitest::Mock.new.tap do |mock|
          mock.expect :update!, true
          mock.expect :destroy, true
          mock.expect :add_note, true, [String, Hash]
          mock.expect :notes, []
          mock.expect :info_notes, []
          mock.expect :warning_notes, []
          mock.expect :error_notes, []
          mock.expect :partitioned!, true
          mock.expect :in_process!, true
          mock.expect :done!, true
          mock.expect :completed!, true
          mock.expect :errored!, true
          mock.expect :partitioned?, false
          mock.expect :in_process?, false
          mock.expect :done?, false
          mock.expect :completed?, false
          mock.expect :errored?, false
        end
      end

      def mock_tracking_model
        @mock_tracking_model ||= Minitest::Mock.new.tap do |mock|
          mock.expect :create!, true
          mock.expect :where, []
          mock.expect :order, []
        end
      end

      def self.included(base)
        base.class_eval do
          def setup
            super
            @mock_workflow_model = nil
            @mock_proxy_model = nil
            @mock_tracking_model = nil
          end
        end
      end
    end
  end
end 