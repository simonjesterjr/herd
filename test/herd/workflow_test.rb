# frozen_string_literal: true

require_relative "../test_helper"
require "test_workflow"

class Herd::WorkflowTest < Herd::Test::TestCase
  def setup
    super
    @workflow = Herd::Workflow.new( name: 'test_workflow',
                                    arguments: { 'key' => 'value' } )
  end

  def test_workflow_initializes_with_default_values
    assert_empty @workflow.jobs
    assert_empty @workflow.proxies
    assert_empty @workflow.arguments
    refute @workflow.stopped
    refute @workflow.persisted
    refute @workflow.parallel_workflows
  end

  def test_workflow_creates_with_arguments
    workflow = TestWorkflow.create("arg1", "arg2")
    assert_equal ["arg1", "arg2"], workflow.arguments
  end

  def test_workflow_finds_by_id
    workflow = Herd::Workflow.create( name: 'test_workflow',
                                      arguments: { 'key' => 'value' } )
    found = Herd::Workflow.find(workflow.id)
    assert_equal workflow.id, found.id
  end

  def test_workflow_raises_not_found_for_invalid_id
    assert_raises(Herd::WorkflowNotFound) do
      Herd::Workflow.find("invalid-id")
    end
  end

  def test_workflow_saves_and_persists
    @workflow.save
    assert @workflow.pending?
    assert @workflow.jobs.empty?
  end

  def test_workflow_stops_and_persists
    @workflow.save
    @workflow.mark_as_stopped
    assert @workflow.stopped?
  end

  def test_workflow_starts_and_persists
    @workflow.save
    @workflow.mark_as_started
    refute @workflow.stopped?
  end

  def test_workflow_resolves_dependencies
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.run(FetchFirstJob, after: PrepareJob)
    @workflow.resolve_dependencies

    job = @workflow.find_job(FetchFirstJob)
    assert_includes job.incoming, PrepareJob.to_s
  end

  def test_workflow_finds_job_by_name
    @workflow.save
    @workflow.run(PrepareJob)
    job = @workflow.find_job(PrepareJob)
    assert_instance_of Herd::Runner, job
    assert_equal PrepareJob, job.klass
  end

  def test_workflow_finds_job_by_klass
    @workflow.save
    @workflow.run(PrepareJob)
    job = @workflow.find_job(PrepareJob.to_s)
    assert_instance_of Herd::Runner, job
    assert_equal PrepareJob, job.klass
  end

  def test_workflow_finished_when_all_jobs_complete
    @workflow.save
    @workflow.jobs.each(&:finish!)
    assert @workflow.finished?
  end

  def test_workflow_running_when_jobs_are_running
    @workflow.save
    @workflow.find_job(PrepareJob).start!
    assert @workflow.running?
  end

  def test_workflow_failed_when_job_fails
    @workflow.save
    @workflow.find_job(PrepareJob).fail!
    assert @workflow.failed?
  end

  def test_workflow_status_changes
    workflow = TestWorkflow.create
    workflow.find_job(PrepareJob).start!
    assert_equal :running, @workflow.status

    workflow.find_job(PrepareJob).finish!
    workflow.find_job(FetchFirstJob).finish!
    workflow.find_job(FetchSecondJob).finish!
    workflow.find_job(NormalizeJob).finish!
    workflow.find_job(PersistFirstJob).finish!
    assert_equal :finished, workflow.status
  end

  def test_workflow_to_json_returns_correct_hash
    result = JSON.parse(@workflow.to_json)
    expected = {
      "id" => String,
      "name" => TestWorkflow.to_s,
      "klass" => TestWorkflow.to_s,
      "status" => "running",
      "total" => 0,
      "finished" => 0,
      "started_at" => nil,
      "finished_at" => nil,
      "stopped" => false,
      "arguments" => []
    }

    expected.each do |key, value|
      if value == String
        assert_instance_of String, result[key]
      else
        assert_equal value, result[key]
      end
    end
  end

  def test_workflow_run_adds_new_job
    @workflow.save
    @workflow.run(PrepareJob)
    assert_instance_of Herd::Runner, @workflow.jobs.first
    assert_equal PrepareJob, @workflow.jobs.first.klass
  end

  def test_workflow_run_with_params
    @workflow.save
    @workflow.run(PrepareJob, params: { something: 1 })
    assert_equal({ something: 1 }, @workflow.jobs.first.params)
  end

  def test_workflow_run_with_dependencies
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.run(FetchFirstJob, after: PrepareJob)
    @workflow.resolve_dependencies

    assert @workflow.jobs.first.outgoing.any? { |job| job.start_with?("FetchFirstJob") }
    assert @workflow.jobs.last.incoming.any? { |job| job.start_with?("PrepareJob") }
  end

  def test_workflow_reloads_state
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.find_job(PrepareJob).start!
    @workflow.save

    reloaded = @workflow.reload
    assert reloaded.find_job(PrepareJob).started?
  end

  def test_workflow_initial_jobs
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.run(FetchFirstJob, after: PrepareJob)
    @workflow.resolve_dependencies

    assert_equal [PrepareJob.to_s], @workflow.initial_jobs.map(&:klass).map(&:to_s)
  end

  def test_workflow_same_workflow_running
    @workflow.save
    refute @workflow.same_workflow_running?

    @workflow.parallel_workflows = true
    refute @workflow.same_workflow_running?
  end

  def test_status_returns_failed_when_failed
    @workflow.save
    @workflow.find_job("PrepareJob").fail!
    @workflow.persist!
    assert_equal :failed, @workflow.reload.status
  end

  def test_save_sets_persisted_to_true
    workflow = TestWorkflow.new( name: 'test_workflow',
                                 arguments: { 'key' => 'value' } )
    workflow.save
    assert workflow.persisted
  end

  def test_save_assigns_new_unique_id
    workflow = TestWorkflow.new( name: 'test_workflow',
                                 arguments: { 'key' => 'value' } )
    workflow.save
    assert_not_nil workflow.id
  end

  def test_save_does_not_assign_new_id_when_persisted
    workflow = TestWorkflow.new( { 'key' => 'value' } )
    workflow.save
    id = workflow.id
    workflow.save
    debugger
    assert_equal id, workflow.id
  end

  def test_continue_enqueues_failed_jobs
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.find_job(PrepareJob).fail!
    assert_not_empty @workflow.jobs.select(&:failed?)

    @workflow.continue

    assert_empty @workflow.jobs.select(&:failed?)
    assert_nil @workflow.find_job(PrepareJob).failed_at
  end

  def test_mark_as_stopped_marks_workflow_as_stopped
    @workflow.save
    assert_change true do
      @workflow.mark_as_stopped
      @workflow.stopped?
    end
  end

  def test_mark_as_started_removes_stopped_flag
    @workflow.status = :stopped
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
    @workflow.save
    @workflow.run(PrepareJob)
    assert_instance_of Herd::Runner, @workflow.find_job(PrepareJob)
  end

  def test_run_allows_passing_additional_params
    workflow = Herd::Workflow.new( name: 'test_workflow',
                                  arguments: { 'key' => 'value' } )
    workflow.run(Herd::Worker, proxy_class: "TestPartition", params: { something: 1 })
    workflow.save
    assert_equal({ something: 1 }, workflow.jobs.first.params)
  end

  def test_run_adds_new_job_when_graph_is_empty
    workflow = Herd::Workflow.new( name: 'test_workflow',
                                   arguments: { 'key' => 'value' } )
    workflow.run(Herd::Worker, proxy_class: "TestPartition")
    workflow.save
    assert_instance_of Herd::Runner, workflow.jobs.first
  end

  def test_run_allows_after_to_accept_array_of_jobs
    tree = Herd::Workflow.new( name: 'test_workflow',
                               arguments: { 'key' => 'value' } )
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
    tree = Herd::Workflow.new( name: 'test_workflow',
                               arguments: { 'key' => 'value' } )
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
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.find_job(PrepareJob).fail!
    assert @workflow.failed?
  end

  def test_failed_returns_false_when_no_jobs_failed
    refute @workflow.failed?
  end

  def test_running_returns_false_when_no_jobs_running
    refute @workflow.running?
  end

  def test_finished_returns_false_when_jobs_unfinished
    refute @workflow.finished?
  end

  def test_status_changes_to_finished_when_all_jobs_complete
    @workflow.save
    @workflow.run(PrepareJob)
    @workflow.run(NormalizeJob)
    @workflow.run(FetchFirstJob)
    @workflow.run(FetchSecondJob)
    @workflow.run(PersistFirstJob)
    @workflow.persist!

    @workflow.find_job(PrepareJob).finish!
    @workflow.find_job(NormalizeJob).finish!
    @workflow.find_job(FetchFirstJob).finish!
    @workflow.persist!
    assert_equal :running, @workflow.reload.status

    @workflow.find_job(FetchSecondJob).finish!
    @workflow.find_job(PersistFirstJob).finish!
    @workflow.persist!
    assert_equal :finished, @workflow.reload.status
  end

  def test_workflow_handles_circular_dependencies
    @workflow.run(PrepareJob)
    @workflow.run(FetchFirstJob, after: PrepareJob)
    @workflow.run(PrepareJob, after: FetchFirstJob) # Creates a cycle
    
    assert_raises(Herd::CircularDependencyError) do
      @workflow.resolve_dependencies
    end
  end

  def test_workflow_handles_invalid_job_class
    assert_raises(Herd::InvalidJobClassError) do
      @workflow.run(InvalidJob)
    end
  end

  def test_workflow_handles_duplicate_jobs
    @workflow.save
    @workflow.run(PrepareJob)
    assert_raises(Herd::DuplicateJobError) do
      @workflow.run(PrepareJob)
    end
  end

  def test_workflow_handles_invalid_dependency
    @workflow.save
    @workflow.run(PrepareJob)
    assert_raises(Herd::InvalidDependencyError) do
      @workflow.run(FetchFirstJob, after: "NonExistentJob")
    end
  end

  def test_workflow_handles_nil_job_id
    @workflow.save
    assert_raises(Herd::InvalidJobNameError) do
      @workflow.find_job(nil)
    end
  end

  def test_workflow_handles_empty_job_name
    @workflow.save
    assert_raises(Herd::InvalidJobNameError) do
      @workflow.find_job("")
    end
  end

  def test_workflow_handles_invalid_state_transition
    @workflow.save
    assert_raises(Herd::InvalidStateTransitionError) do
      @workflow.mark_as_started
    end
  end

  def test_workflow_handles_concurrent_modification
    @workflow.save
    @workflow.run(PrepareJob)
    
    # Simulate concurrent modification
    @workflow.instance_variable_get(:@model).expect :save, false
    
    assert_raises(Herd::ConcurrentModificationError) do
      @workflow.save
    end
  end

end 