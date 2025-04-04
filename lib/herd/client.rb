# frozen_string_literal: true

require 'redis'
require 'redis-classy'
require 'concurrent-ruby'

class Herd::Client
  attr_reader :configuration

  @@redis_connection = Concurrent::ThreadLocalVar.new(nil)

  def self.redis_connection
    @redis_connection ||= begin
      instance = Redis.new(url: Herd.configuration.redis_url)
      RedisClassy.redis = instance
      instance
    end
  end

  def self.redis
    redis_connection
  end

  def initialize(config = Herd.configuration)
    @configuration = config
  end

  def configure
    yield configuration
  end

  def create_workflow(name)
    begin
      name.constantize.create
    rescue NameError
      raise WorkflowNotFound, "Workflow with given name doesn't exist"
    end
  end

  def start_workflow(workflow, arguments = [], job_names = [])
    workflow.mark_as_started
    persist_workflow(workflow)

    jobs = if job_names.empty?
      workflow.initial_jobs
    else
      job_names.map { |name| workflow.find_job(name) }
    end

    jobs.each do |job|
      enqueue_job(workflow.id, job)
    end
  end

  def stop_workflow(id)
    workflow = find_workflow(id)
    workflow.mark_as_stopped
    persist_workflow(workflow)
  end

  def next_free_job_id(workflow_id, job_klass)
    job_id = nil

    loop do
      job_id = SecureRandom.uuid
      available = !redis.with { |conn| conn.hexists("herd.jobs.#{workflow_id}.#{job_klass}", job_id) }

      break if available
    end

    job_id
  end

  def next_free_workflow_id
    id = nil
    loop do
      id = SecureRandom.uuid
      available = !redis.with { |conn| conn.exists?("herd.workflow.#{id}") }

      break if available
    end

    id
  end

  def all_workflows
    Herd::Models::Workflow.all.map do |workflow_model|
      find_workflow(workflow_model.id)
    end
  end

  def all_proxies
    Herd::Models::Proxy.all
  end

  def find_workflow(id)
    workflow_model = Herd::Models::Workflow.find_by(id: id)
    raise ::Herd::WorkflowNotFound, "Workflow with given id ( #{id} ) doesn't exist" if workflow_model.nil?

    # Get job data from Redis
    keys = redis.with { |conn| conn.scan_each(match: "herd.jobs.#{id}.*") }
    nodes = keys.each_with_object([]) do |key, array|
      array.concat redis.with { |conn| conn.hvals(key).map { |json| Herd::JSON.decode(json, symbolize_keys: true) } }
    end

    workflow_from_hash(workflow_model.attributes.symbolize_keys, nodes)
  end

  def find_proxy(id)
    Herd::Models::Proxy.find_by(id: id)
  end

  def find_proxy_by_proxy_id(id)
    Herd::Models::Proxy.find_by(id: id)
  end

  def find_proxy_by_job_id(job_id)
    Herd::Models::Proxy.find_by(job_id: job_id)
  end

  def persist_workflow(workflow)
    # Persist workflow state to PostgreSQL
    workflow.update!(
      name: workflow.name,
      arguments: workflow.arguments,
      status: 'stopped',
      started_at: workflow.started_at,
      finished_at: workflow.finished_at
    )

    # Persist job data to Redis
    workflow.jobs.each { |job| persist_job(workflow.id, job) }

    true
  end

  def persist_proxy(proxy)
    proxy.save!
  end

  def persist_job(workflow_id, job)
    redis.with { |conn| conn.hset("herd.jobs.#{workflow_id}.#{job.klass}", job.id, job.to_json) }
  end

  def find_job(workflow_id, job_name)
    job_name_match = /(?<klass>\w*[^-])-(?<identifier>.*)/.match(job_name)

    data = if job_name_match
      find_job_by_klass_and_id(workflow_id, job_name)
    else
      find_job_by_klass(workflow_id, job_name)
    end

    return nil if data.nil?

    data = Herd::JSON.decode(data, symbolize_keys: true)
    Herd::Runner.from_hash(data)
  end

  def destroy_workflow(workflow)
    # Delete workflow from PostgreSQL
    workflow.destroy

    # Delete job data from Redis
    workflow.jobs.each { |job| destroy_job(workflow.id, job) }
  end

  def destroy_proxy(proxy)
    proxy.destroy
  end

  def destroy_job(workflow_id, job)
    redis.with { |conn| conn.del("herd.jobs.#{workflow_id}.#{job.klass}") }
  end

  def expire_workflow(workflow, ttl = nil)
    ttl ||= configuration.ttl
    redis.with { |conn| conn.expire("herd.workflows.#{workflow.id}", ttl) }
    workflow.jobs.each { |job| expire_job(workflow.id, job, ttl) }
  end

  def expire_job(workflow_id, job, ttl = nil)
    ttl ||= configuration.ttl
    redis.with { |conn| conn.expire("herd.jobs.#{workflow_id}.#{job.klass}", ttl) }
  end

  def enqueue_job(workflow_id, job)
    # reset workflow statuses
    job.enqueue!

    persist_job(workflow_id, job)
    queue = job.queue || configuration.namespace

    job.klass.to_s.constantize.set(queue: queue).perform_in(5, *[workflow_id])
  end

  private

  def find_job_by_klass_and_id(workflow_id, job_name)
    job_klass, job_id = job_name.split('|')

    redis.with { |conn| conn.hget("herd.jobs.#{workflow_id}.#{job_klass}", job_id) }
  end

  def find_job_by_klass(workflow_id, job_name)
    new_cursor, result = redis.with { |conn| conn.hscan("herd.jobs.#{workflow_id}.#{job_name}", 0, count: 1) }
    return nil if result.empty?

    job_id, job = *result[0]

    job
  end

  def workflow_from_hash(hash, nodes = [])
    flow = Object.const_get(hash[:name]).new(*hash[:arguments])
    flow.jobs = []
    flow.proxies = []
    flow.status = hash.fetch( :status, :pending )
    flow.id = hash[:id]

    flow.jobs = nodes.map do |node|
      Herd::Runner.from_hash(node)
    end

    flow
  end

  def redis(&block)
    self.class.redis_connection
  end
end
