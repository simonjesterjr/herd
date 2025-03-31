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
    flow
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
      available = !redis.with { |conn| conn.hexists("clockworx.jobs.#{workflow_id}.#{job_klass}", job_id) }

      break if available
    end

    job_id
  end

  def next_free_workflow_id
    id = nil
    loop do
      id = SecureRandom.uuid
      available = !redis.with { |conn| conn.exists?("clockworx.workflow.#{id}") }

      break if available
    end

    id
  end

  def all_workflows
    redis.with { |conn| conn.scan_each(match: "clockworx.workflows.*") }.each do |key|
      id = key.sub("clockworx.workflows.", "")
      find_workflow(id)
    end.map
  end

  def find_workflow(id)
    data = redis.with { |conn| conn.get("clockworx.workflows.#{id}") }
    raise ::Herd::WorkflowNotFound, "Workflow with given id ( #{id} ) doesn't exist" if data.nil?

    hash = Herd::JSON.decode(data, symbolize_keys: true)
    keys = redis.with { |conn| conn.scan_each(match: "clockworx.jobs.#{id}.*") }
    nodes = keys.each_with_object([]) do |key, array|
      array.concat redis.with { |conn| conn.hvals(key).map { |json| Herd::JSON.decode(json, symbolize_keys: true) } }
    end

    workflow_from_hash(hash, nodes)
  end

  def persist_workflow(workflow)
    redis.with { |conn| conn.set("clockworx.workflows.#{workflow.id}", workflow.to_json) }

    workflow.jobs.each { |job| persist_job(workflow.id, job) }
    workflow.mark_as_persisted

    if workflow.finished?
      # to do persist status of the workflow
    end

    true
  end

  def persist_job(workflow_id, job)
    redis.with { |conn| conn.hset("clockworx.jobs.#{workflow_id}.#{job.klass}", job.id, job.to_json) }
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
    redis.with { |conn| conn.del("clockworx.workflows.#{workflow.id}") }
    workflow.jobs.each { |job| destroy_job(workflow.id, job) }
  end

  def destroy_job(workflow_id, job)
    redis.with { |conn| conn.del("clockworx.jobs.#{workflow_id}.#{job.klass}") }
  end

  def expire_workflow(workflow, ttl = nil)
    ttl ||= configuration.ttl
    redis.with { |conn| conn.expire("clockworx.workflows.#{workflow.id}", ttl) }
    workflow.jobs.each { |job| expire_job(workflow.id, job, ttl) }
  end

  def expire_job(workflow_id, job, ttl = nil)
    ttl ||= configuration.ttl
    redis.with { |conn| conn.expire("clockworx.jobs.#{workflow_id}.#{job.klass}", ttl) }
  end

  def enqueue_job(workflow_id, job)
    # reset workflow statuses
    job.enqueue!

    persist_job(workflow_id, job)
    queue = job.queue || configuration.namespace

    # Herd::Worker.set(queue: queue).perform_in(10, *[workflow_id, job.name])
    job.klass.to_s.constantize.set(queue: queue).perform_in(5, *[workflow_id])
  end

  private

    def find_job_by_klass_and_id(workflow_id, job_name)
      job_klass, job_id = job_name.split('|')

      redis.with { |conn| conn.hget("clockworx.jobs.#{workflow_id}.#{job_klass}", job_id) }
    end

    def find_job_by_klass(workflow_id, job_name)
      new_cursor, result = redis.with { |conn| conn.hscan("clockworx.jobs.#{workflow_id}.#{job_name}", 0, count: 1) }
      return nil if result.empty?

      job_id, job = *result[0]

      job
    end

    def workflow_from_hash(hash, nodes = [])
      flow = Object.const_get(hash[:klass]).new(*hash[:arguments])
      flow.jobs = []
      flow.proxies = []
      flow.stopped = hash.fetch(:stopped, false)
      flow.id = hash[:id]

      flow.jobs = nodes.map do |node|
        Herd::Runner.from_hash(node)
      end

      flow.proxies = flow.jobs.map(&:proxy)

      flow
    end

    # rubocop:disable Style/ExplicitBlockArgument
    def redis(&block)
      self.class.redis_connection
    end
end
