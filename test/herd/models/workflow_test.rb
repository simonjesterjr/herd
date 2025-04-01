require 'test_helper'

module Herd::Test
  class WorkflowTest < TestCase
    def setup
      super
      @workflow = Herd::Models::Workflow.new(
        name: 'test_workflow',
        arguments: { 'key' => 'value' }
      )
    end

    def test_workflow_creation
      assert @workflow.save
      assert_equal 'test_workflow', @workflow.name
      assert_equal({ 'key' => 'value' }, @workflow.arguments)
      assert_nil @workflow.started_at
      assert_nil @workflow.finished_at
      assert_equal 'pending', @workflow.status
      refute @workflow.stopped
    end

    def test_workflow_start
      @workflow.save
      @workflow.start!
      
      assert_equal 'running', @workflow.status
      assert_not_nil @workflow.started_at
      assert_nil @workflow.finished_at
    end

    def test_workflow_stop
      @workflow.save
      @workflow.start!
      @workflow.stop!
      
      assert_equal 'stopped', @workflow.status
      assert_not_nil @workflow.started_at
      assert_not_nil @workflow.finished_at
      assert @workflow.stopped
    end

    def test_workflow_finish
      @workflow.save
      @workflow.start!
      @workflow.finish!
      
      assert_equal 'completed', @workflow.status
      assert_not_nil @workflow.started_at
      assert_not_nil @workflow.finished_at
      refute @workflow.stopped
    end

    def test_workflow_fail
      @workflow.save
      @workflow.start!
      @workflow.fail!
      
      assert_equal 'failed', @workflow.status
      assert_not_nil @workflow.started_at
      assert_not_nil @workflow.finished_at
      refute @workflow.stopped
    end

    def test_workflow_proxies_association
      @workflow.save
      
      proxy = @workflow.proxies.create!(
        name: 'test_proxy',
        job_class: 'TestJob',
        job_id: '123'
      )
      
      assert_equal 1, @workflow.proxies.count
      assert_equal proxy, @workflow.proxies.first
      assert_equal @workflow, proxy.workflow
    end

    def test_workflow_trackings_association
      @workflow.save
      
      tracking = @workflow.trackings.create!(
        level: 'info',
        message: 'Test message'
      )
      
      assert_equal 1, @workflow.trackings.count
      assert_equal tracking, @workflow.trackings.first
      assert_equal @workflow, tracking.trackable
    end

    def test_workflow_validation
      workflow = Herd::Models::Workflow.new
      refute workflow.save
      assert_includes workflow.errors[:name], "can't be blank"
    end

    def test_workflow_status_transitions
      @workflow.save
      
      assert_equal 'pending', @workflow.status
      
      @workflow.start!
      assert_equal 'running', @workflow.status
      
      @workflow.stop!
      assert_equal 'stopped', @workflow.status
      
      @workflow.start!
      assert_equal 'running', @workflow.status
      
      @workflow.finish!
      assert_equal 'completed', @workflow.status
      
      assert_raises(ActiveRecord::RecordInvalid) do
        @workflow.start!
      end
    end

    def test_workflow_duration
      @workflow.save
      @workflow.start!
      sleep 0.1
      @workflow.finish!
      
      assert_not_nil @workflow.duration
      assert @workflow.duration >= 0.1
    end
  end
end 