# frozen_string_literal: true
require "test_helper"
require "test_workflow"

module Herd
  module Test
    class TrackingTest < TestCase
      def test_workflow_adds_note_on_state_change
        workflow = TestWorkflow.new
        workflow.mark_as_started
        assert_equal "Workflow started", workflow.notes.first.note
        assert_equal "info", workflow.notes.first.level
      end

      def test_proxy_adds_note_on_state_change
        proxy = Herd::Models::Proxy.new(workflow_id: "test")
        proxy.in_process!
        assert_equal "Job started processing", proxy.notes.first.note
        assert_equal "info", proxy.notes.first.level
      end

      def test_add_note_with_metadata
        workflow = TestWorkflow.new( name: 'test_workflow',
                                     arguments: { 'key' => 'value' } )
        workflow.save!

        workflow.add_note("Test note", metadata: { key: "value" })
        note = workflow.notes.first
        assert_equal "Test note", note.note
        assert_equal({ "key" => "value" }, note.metadata)
      end

      def test_add_note_with_different_levels
        workflow = TestWorkflow.new( name: 'test_workflow',
                                     arguments: { 'key' => 'value' } )
        workflow.save! 
        # debugger

        workflow.add_note("Info note", level: "info")
        workflow.add_note("Warning note", level: "warning")
        workflow.add_note("Error note", level: "error")

        assert_equal "Info note", workflow.info_notes.first.note
        assert_equal "Warning note", workflow.warning_notes.first.note
        assert_equal "Error note", workflow.error_notes.first.note
      end

      def test_notes_are_ordered_by_created_at
        workflow = TestWorkflow.new
        workflow.add_note("First note")
        workflow.add_note("Second note")
        workflow.add_note("Third note")

        notes = workflow.notes
        assert_equal "Third note", notes[0].note
        assert_equal "Second note", notes[1].note
        assert_equal "First note", notes[2].note
      end
    end
  end
end 