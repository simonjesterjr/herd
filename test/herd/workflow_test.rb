# frozen_string_literal: true

require_relative "../test_helper"
require "test_workflow"

class Herd::WorkflowTest < Herd::TestCase
  def setup
    super
    @workflow = TestWorkflow.create
  end

  def test_initialize_passes_constructor_arguments
    klass = Class.new(Herd::Workflow) do
      def configure(*args)
        run FetchFirstJob
        run PersistFirstJob, after: FetchFirstJob
      end
    end

    workflow = klass.new("arg1", "arg2")
    assert_equal ["arg1", "arg2"], workflow.arguments
  end

  def test_status_returns_failed_when_failed
    @workflow.find_job("Prepare").fail!
    @workflow.persist!
    assert_equal :failed, @workflow.reload.status
  end

  def test_save_sets_persisted_to_true
    workflow = TestWorkflow.new
    workflow.save
    assert workflow.persisted
  end

  def test_save_assigns_new_unique_id
    workflow = TestWorkflow.new
    workflow.save
    assert_not_nil workflow.id
  end

  def test_save_does_not_assign_new_id_when_persisted
    workflow = TestWorkflow.new
    workflow.save
    id = workflow.id
    workflow.save
    assert_equal id, workflow.id
  end

  def test_continue_enqueues_failed_jobs
    @workflow.find_job("Prepare").fail!
    assert_not_empty @workflow.jobs.select(&:failed?)

    @workflow.continue

    assert_empty @workflow.jobs.select(&:failed?)
    assert_nil @workflow.find_job("Prepare").failed_at
  end

  def test_mark_as_stopped_marks_workflow_as_stopped
    assert_change true do
      @workflow.mark_as_stopped
      @workflow.stopped?
    end
  end

  def test_mark_as_started_removes_stopped_flag
    @workflow.stopped = true
    assert_change false do
      @workflow.mark_as_started
      @workflow.stopped?
    end
  end

  def test_to_json_returns_correct_hash
    klass = Class.new(Herd::Workflow) do
      def configure(*args)
        run FetchFirstJob, proxy_class: "RunningPartition"
        run PersistFirstJob, proxy_class: "RunningPartition", after: FetchFirstJob
      end
    end

    result = JSON.parse(klass.create("arg1", "arg2").to_json)
    expected = {
      "id" => String,
      "name" => klass.to_s,
      "klass" => klass.to_s,
      "status" => "running",
      "total" => 2,
      "finished" => 0,
      "started_at" => nil,
      "finished_at" => nil,
      "stopped" => false,
      "arguments" => ["arg1", "arg2"]
    }

    expected.each do |key, value|
      if value == String
        assert_instance_of String, result[key]
      else
        assert_equal value, result[key]
      end
    end
  end

  def test_find_job_finds_job_runner_by_name
    assert_instance_of Herd::Runner, @workflow.find_job("PersistFirstJob")
  end

  def test_run_allows_passing_additional_params
    workflow = Herd::Workflow.new
    workflow.run(Herd::Worker, proxy_class: "TestPartition", params: { something: 1 })
    workflow.save
    assert_equal({ something: 1 }, workflow.jobs.first.params)
  end

  def test_run_adds_new_job_when_graph_is_empty
    workflow = Herd::Workflow.new
    workflow.run(Herd::Worker, proxy_class: "TestPartition")
    workflow.save
    assert_instance_of Herd::Runner, workflow.jobs.first
  end

  def test_run_allows_after_to_accept_array_of_jobs
    tree = Herd::Workflow.new
    klass1 = Class.new(Herd::Worker)
    klass2 = Class.new(Herd::Worker)
    klass3 = Class.new(Herd::Worker)

    tree.run(klass1, proxy_class: "TestPartition")
    tree.run(klass2, proxy_class: "TestPartition", after: [klass1, klass3])
    tree.run(klass3, proxy_class: "TestPartition")

    tree.resolve_dependencies

    assert_match_array jobs_with_id([klass2.to_s]), tree.jobs.first.outgoing
  end

  def test_run_allows_before_to_accept_array_of_jobs
    tree = Herd::Workflow.new
    klass1 = Class.new(Herd::Worker)
    klass2 = Class.new(Herd::Worker)
    klass3 = Class.new(Herd::Worker)

    tree.run(klass1, proxy_class: "TestPartition")
    tree.run(klass2, proxy_class: "TestPartition", before: [klass1, klass3])
    tree.run(klass3, proxy_class: "TestPartition")

    tree.resolve_dependencies

    assert_match_array jobs_with_id([klass2.to_s]), tree.jobs.first.incoming
  end

  def test_failed_returns_true_when_job_failed
    @workflow.find_job("Prepare").fail!
    assert @workflow.failed?
  end

  def test_failed_returns_false_when_no_jobs_failed
    refute @workflow.failed?
  end

  def test_running_returns_false_when_no_jobs_running
    refute @workflow.running?
  end

  def test_running_returns_true_when_jobs_are_running
    @workflow.find_job("Prepare").start!
    assert @workflow.running?
  end

  def test_finished_returns_false_when_jobs_unfinished
    refute @workflow.finished?
  end

  def test_finished_returns_true_when_all_jobs_finished
    @workflow.jobs.each(&:finish!)
    assert @workflow.finished?
  end

  def test_status_changes_to_finished_when_all_jobs_complete
    @workflow.find_job("Prepare").finish!
    @workflow.find_job("NormalizeJob").finish!
    @workflow.find_job("FetchFirstJob").finish!
    @workflow.persist!
    assert_equal :running, @workflow.reload.status

    @workflow.find_job("FetchSecondJob").finish!
    @workflow.find_job("PersistFirstJob").finish!
    @workflow.persist!
    assert_equal :finished, @workflow.reload.status
  end

  private

  def jobs_with_id(job_names)
    job_names.map { |name| { "id" => String, "name" => name } }
  end
end 