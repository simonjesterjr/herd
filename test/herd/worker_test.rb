# frozen_string_literal: true

require_relative "../test_helper"
require "test_workflow"

# Test classes for worker tests
class FailingWorker < Herd::Worker
  def perform(workflow_id)
    setup_job("FailingJob")
    mark_as_failed
  end
end

class FailingWorkflow < Herd::Workflow
  def configure
    run FailingWorker
  end
end

class OkayJob < Herd::Worker
  def perform(workflow_id)
    setup_job("OkayJob")
    mark_as_finished
  end
end

class OkayWorkflow < Herd::Workflow
  def configure
    run OkayJob
  end
end

class Herd::WorkerTest < Herd::TestCase
  def setup
    super
    @workflow = TestWorkflow.new
    @workflow_id = @workflow.id
  end

  def test_worker_should_fail
    worker = FailingWorker.new
    worker.clockworx(@workflow_id, "FailingJob") do
      raise StandardError, "Worker failed"
    end
  rescue StandardError
    assert worker.failed?
  end

  def test_worker_should_succeed
    worker = OkayJob.new
    worker.clockworx(@workflow_id, "OkayJob") do
      # Do nothing, just succeed
    end
    assert !worker.failed?
  end

  def test_worker_should_setup_job
    worker = OkayJob.new
    worker.setup(@workflow_id)
    assert_equal "OkayJob", worker.job.name
  end

  def test_worker_should_teardown_job
    worker = OkayJob.new
    worker.setup(@workflow_id)
    worker.teardown
    assert worker.job.finished?
  end

  def test_worker_should_handle_incoming_payloads
    worker = OkayJob.new
    worker.setup(@workflow_id)
    assert_equal [], worker.job.payloads
  end

  def test_worker_should_handle_outgoing_jobs
    worker = OkayJob.new
    worker.setup(@workflow_id)
    worker.teardown
    assert_equal [], worker.job.outgoing
  end

  def test_perform_marks_job_as_failed_when_worker_fails
    transaction = TestPartition.create
    failed = FailedPartition.create(parent_id: transaction.id)

    workflow = FailingWorkflow.create(transaction.id)
    
    assert_raises(NameError) do
      FailingWorker.new.perform(workflow.id)
    end

    assert @client.find_job(workflow.id, "FailingWorker").failed?
  end

  def test_perform_marks_job_as_succeeded_when_completes_successfully
    job = @workflow.jobs[0]
    assert job.klass.respond_to?(:mark_as_finished)
    
    job.klass.new.perform(@workflow.id)
  end

  def test_perform_enqueues_another_job_when_fails_to_enqueue_outgoing_jobs
    RedisMutex.stub :with_lock, ->(*args) { raise RedisMutex::LockError } do
      subject.perform(@workflow.id)
      assert_empty Herd::Worker.jobs(@workflow.id, jobs_with_id(["FetchFirstJob", "FetchSecondJob"]))
    end

    RedisMutex.stub :with_lock, ->(*args) { true } do
      perform_one
      assert_not_empty Herd::Worker.jobs(@workflow.id, jobs_with_id(["FetchFirstJob", "FetchSecondJob"]))
    end
  end

  def test_perform_calls_job_perform_method
    spy = Minitest::Mock.new
    spy.expect :some_method, nil

    transaction = TestPartition.create
    okay = TestPartition.create(parent_id: transaction.id)
    workflow = OkayWorkflow.create(transaction.id)
    subject.perform(workflow.id)
    spy.verify
  end

  def test_perform_calls_redlock_with_customizable_duration_and_interval
    client = Minitest::Mock.new
    client.expect :lock, true, [String, { block: 5, sleep: 0.5 }]
    client.expect :lock, true, [String, { block: 5, sleep: 0.5 }]

    Redlock::Client.stub :new, client do
      subject.perform(@workflow.id)
    end

    client.verify
  end

  private

  def jobs_with_id(job_names)
    job_names.map { |name| { "id" => String, "name" => name } }
  end
end 

class FailingWorker < Herd::Worker
  def perform(workflow_id)
    @workflow_id = workflow_id
    setup_job("FailingWorker")
    raise NameError
  rescue NameError => ex
    mark_as_failed
    raise ex
  end
end

class FailingWorkflow < Herd::Workflow
  def configure(transaction_id)
    run FailingWorker, proxy_class: "FailedPartition", transaction_id: transaction_id
  end
end