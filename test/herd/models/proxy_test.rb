require 'test_helper'

module Herd::Test
  class ProxyTest < TestCase
    def setup
      super
      @workflow = Herd::Models::Workflow.create!(
        name: 'test_workflow',
        arguments: { 'key' => 'value' }
      )
      @proxy = @workflow.proxies.new(
        name: 'test_proxy',
        job_class: 'TestJob',
        job_id: '123'
      )
    end

    def test_proxy_creation
      assert @proxy.save
      assert_equal 'test_proxy', @proxy.name
      assert_equal 'TestJob', @proxy.job_class
      assert_equal '123', @proxy.job_id
      assert_nil @proxy.started_at
      assert_nil @proxy.finished_at
      assert_equal 'pending', @proxy.status
      assert_equal @workflow, @proxy.workflow
    end

    def test_proxy_start
      @proxy.save
      @proxy.start!
      
      assert_equal 'running', @proxy.status
      assert_not_nil @proxy.started_at
      assert_nil @proxy.finished_at
    end

    def test_proxy_finish
      @proxy.save
      @proxy.start!
      @proxy.finish!
      
      assert_equal 'completed', @proxy.status
      assert_not_nil @proxy.started_at
      assert_not_nil @proxy.finished_at
    end

    def test_proxy_fail
      @proxy.save
      @proxy.start!
      @proxy.fail!
      
      assert_equal 'failed', @proxy.status
      assert_not_nil @proxy.started_at
      assert_not_nil @proxy.finished_at
    end

    def test_proxy_trackings_association
      @proxy.save
      
      tracking = @proxy.trackings.create!(
        level: 'info',
        message: 'Test message'
      )
      
      assert_equal 1, @proxy.trackings.count
      assert_equal tracking, @proxy.trackings.first
      assert_equal @proxy, tracking.trackable
    end

    def test_proxy_validation
      proxy = @workflow.proxies.new
      refute proxy.save
      assert_includes proxy.errors[:name], "can't be blank"
      assert_includes proxy.errors[:job_class], "can't be blank"
      assert_includes proxy.errors[:job_id], "can't be blank"
    end

    def test_proxy_status_transitions
      @proxy.save
      
      assert_equal 'pending', @proxy.status
      
      @proxy.start!
      assert_equal 'running', @proxy.status
      
      @proxy.finish!
      assert_equal 'completed', @proxy.status
      
      assert_raises(ActiveRecord::RecordInvalid) do
        @proxy.start!
      end
    end

    def test_proxy_duration
      @proxy.save
      @proxy.start!
      sleep 0.1
      @proxy.finish!
      
      assert_not_nil @proxy.duration
      assert @proxy.duration >= 0.1
    end

    def test_proxy_add_note
      @proxy.save
      
      @proxy.add_note('Test note', level: 'info')
      assert_equal 1, @proxy.trackings.count
      
      tracking = @proxy.trackings.first
      assert_equal 'Test note', tracking.message
      assert_equal 'info', tracking.level
    end

    def test_proxy_add_note_with_metadata
      @proxy.save
      
      @proxy.add_note('Test note', level: 'info', metadata: { 'key' => 'value' })
      assert_equal 1, @proxy.trackings.count
      
      tracking = @proxy.trackings.first
      assert_equal({ 'key' => 'value' }, tracking.metadata)
    end

    def test_proxy_notes_by_level
      @proxy.save
      
      @proxy.add_note('Info note', level: 'info')
      @proxy.add_note('Warning note', level: 'warning')
      @proxy.add_note('Error note', level: 'error')
      
      assert_equal 1, @proxy.info_notes.count
      assert_equal 1, @proxy.warning_notes.count
      assert_equal 1, @proxy.error_notes.count
      
      assert_equal 'Info note', @proxy.info_notes.first.message
      assert_equal 'Warning note', @proxy.warning_notes.first.message
      assert_equal 'Error note', @proxy.error_notes.first.message
    end
  end
end 