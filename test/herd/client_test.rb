# frozen_string_literal: true

require_relative "../test_helper"
require "test_workflow"

class ParameterTestWorkflow < Herd::Workflow
  def configure(parameter)
    run PrepareJob if parameter
  end
end

class Herd::ClientTest < Herd::TestCase
  def setup
    super
    @client = Herd::Client.new(Herd::Configuration.new(
      herdfile: "test/fixtures/Herdfile",
      redis_url: "redis://localhost:6379/1"
    ))
  end

  def test_find_workflow_raises_workflow_not_found_when_workflow_doesnt_exist
    assert_raises(Herd::WorkflowNotFound) do
      @client.find_workflow("nope")
    end
  end

  def test_find_workflow_returns_workflow_object_when_exists
    expected_workflow = TestWorkflow.create
    workflow = @client.find_workflow(expected_workflow.id)

    assert_equal expected_workflow.id, workflow.id
    assert_match_array expected_workflow.jobs.map(&:name), workflow.jobs.map(&:name)
  end

  def test_find_workflow_returns_workflow_object_with_parameters
    expected_workflow = ParameterTestWorkflow.create(true)
    workflow = @client.find_workflow(expected_workflow.id)

    assert_equal expected_workflow.id, workflow.id
    assert_match_array expected_workflow.jobs.map(&:name), workflow.jobs.map(&:name)
  end

  def test_start_workflow_enqueues_next_jobs
    workflow = TestWorkflow.create
    assert_difference -> { Sidekiq::Queues["herd"].size }, 1 do
      @client.start_workflow(workflow)
    end
  end

  def test_start_workflow_removes_stopped_flag
    workflow = TestWorkflow.create
    workflow.mark_as_stopped
    workflow.persist!

    assert_change false do
      @client.start_workflow(workflow)
      @client.find_workflow(workflow.id).stopped?
    end
  end

  def test_start_workflow_marks_jobs_as_enqueued
    workflow = TestWorkflow.create
    @client.start_workflow(workflow)
    job = workflow.reload.find_job("Prepare")
    assert job.enqueued?
  end

  def test_stop_workflow_marks_workflow_as_stopped
    workflow = TestWorkflow.create
    assert_change true do
      @client.stop_workflow(workflow.id)
      @client.find_workflow(workflow.id).stopped?
    end
  end

  def test_persist_workflow_persists_json_dump
    job = Minitest::Mock.new
    job.expect :to_json, "json"
    workflow = Minitest::Mock.new
    workflow.expect :id, "abcd"
    workflow.expect :jobs, [job, job, job]
    workflow.expect :to_json, '"json"'
    workflow.expect :mark_as_persisted, nil

    @client.expect :persist_job, nil, [workflow.id, job]
    @client.expect :persist_job, nil, [workflow.id, job]
    @client.expect :persist_job, nil, [workflow.id, job]

    @client.persist_workflow(workflow)

    assert_equal 1, redis.keys("herd.workflows.abcd").length
    job.verify
    workflow.verify
  end

  def test_destroy_workflow_removes_all_redis_keys
    workflow = TestWorkflow.create
    assert_equal 1, redis.keys("herd.workflows.#{workflow.id}").length
    assert_equal 5, redis.keys("herd.jobs.#{workflow.id}.*").length

    @client.destroy_workflow(workflow)

    assert_empty redis.keys("herd.workflows.#{workflow.id}")
    assert_empty redis.keys("herd.jobs.#{workflow.id}.*")
  end

  def test_expire_workflow_sets_ttl_for_all_redis_keys
    workflow = TestWorkflow.create
    ttl = 2000

    @client.expire_workflow(workflow, ttl)

    assert_equal ttl, redis.ttl("herd.workflows.#{workflow.id}")
    workflow.jobs.each do |job|
      assert_equal ttl, redis.ttl("herd.jobs.#{workflow.id}.#{job.klass}")
    end
  end

  def test_persist_job_persists_json_dump_in_redis
    job = Herd::Runner.new(klass: BobJob.new, proxy_class: "TestProxy}")
    @client.persist_job("deadbeef", job)
    assert_equal 1, redis.keys("herd.jobs.deadbeef.*").length
  end

  def test_all_workflows_returns_all_registered_workflows
    workflow = TestWorkflow.create
    workflows = @client.all_workflows
    assert_equal [workflow.id], workflows.map(&:id)
  end

  def test_handles_outdated_data_format
    workflow = TestWorkflow.create

    # malform the data
    hash = Herd::JSON.decode(redis.get("herd.workflows.#{workflow.id}"), symbolize_keys: true)
    hash.delete(:stopped)
    redis.set("herd.workflows.#{workflow.id}", Herd::JSON.encode(hash))

    assert_nothing_raised do
      workflow = @client.find_workflow(workflow.id)
      refute workflow.stopped?
    end
  end

  def test_client_finds_workflow
    workflow = TestWorkflow.create
    found = @client.find_workflow(workflow.id)
    assert_equal workflow.id, found.id
  end

  def test_client_finds_proxy
    proxy = TestProxy.create
    found = @client.find_proxy(proxy.id)
    assert_equal proxy.id, found.id
  end

  def test_client_persists_workflow
    workflow = TestWorkflow.new
    @client.persist_workflow(workflow)
    assert workflow.persisted
  end

  def test_client_persists_proxy
    proxy = TestProxy.new
    @client.persist_proxy(proxy)
    assert proxy.persisted
  end

  def test_client_destroys_workflow
    workflow = TestWorkflow.create
    @client.destroy_workflow(workflow)
    assert_raises(Herd::WorkflowNotFound) do
      @client.find_workflow(workflow.id)
    end
  end

  def test_client_destroys_proxy
    proxy = TestProxy.create
    @client.destroy_proxy(proxy)
    assert_raises(Herd::ProxyNotFound) do
      @client.find_proxy(proxy.id)
    end
  end

  def test_client_all_workflows
    workflow1 = TestWorkflow.create
    workflow2 = TestWorkflow.create
    workflows = @client.all_workflows
    assert_equal 2, workflows.size
    assert_includes workflows.map(&:id), workflow1.id
    assert_includes workflows.map(&:id), workflow2.id
  end

  def test_client_all_proxies
    proxy1 = TestProxy.create
    proxy2 = TestProxy.create
    proxies = @client.all_proxies
    assert_equal 2, proxies.size
    assert_includes proxies.map(&:id), proxy1.id
    assert_includes proxies.map(&:id), proxy2.id
  end

  def test_client_finds_workflow_by_job_id
    workflow = TestWorkflow.create
    job = workflow.find_job(PrepareJob)
    found = @client.find_workflow_by_job_id(job.id)
    assert_equal workflow.id, found.id
  end

  def test_client_finds_proxy_by_job_id
    proxy = TestProxy.create
    job = proxy.find_job(PrepareJob)
    found = @client.find_proxy_by_job_id(job.id)
    assert_equal proxy.id, found.id
  end

  def test_client_finds_workflow_by_proxy_id
    workflow = TestWorkflow.create
    proxy = TestProxy.create(parent_id: workflow.id)
    found = @client.find_workflow_by_proxy_id(proxy.id)
    assert_equal workflow.id, found.id
  end

  def test_client_finds_proxy_by_proxy_id
    proxy = TestProxy.create
    child = TestProxy.create(parent_id: proxy.id)
    found = @client.find_proxy_by_proxy_id(child.id)
    assert_equal proxy.id, found.id
  end

  private

  def redis
    @redis ||= Redis.new(url: "redis://localhost:6379/1")
  end
end 