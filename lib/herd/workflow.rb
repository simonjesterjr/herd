require 'securerandom'

class Herd::Workflow
  attr_accessor :id, :jobs, :proxies, :stopped,
                :persisted, :arguments, :parallel_workflows

  def initialize(*args)
    @id = id
    @jobs = []
    @proxies = []
    @dependencies = []
    @persisted = false
    @stopped = false
    @parallel_workflows = false
    @arguments = args

    setup
  end

  def self.find(id)
    attempts ||= 0
    Herd::Client.new.find_workflow(id)
  rescue RuntimeError => e
    raise e unless attempts < 5

    attempts += 1
    sleep rand / 100
    retry
  end

  def self.create(*args)
    flow = new(*args)
    flow.save
    flow
  end

  def continue
    client = Herd::Client.new
    failed_jobs = jobs.select(&:failed?)

    failed_jobs.each do |job|
      client.enqueue_job(id, job)
    end
  end

  def save
    persist!
  end

  def configure(*args); end

  def mark_as_stopped
    @stopped = true
  end

  def start!
    # TODO: need a way to finalize or finish or delete un-run workflows
    # msg = "#{name} is already running in another process"
    # raise Herd::SameWorkflowRunning, msg if same_workflow_running?

    client.start_workflow(self)
  end

  def persist!
    client.persist_workflow(self)
  end

  def expire!( ttl = nil )
    client.expire_workflow(self, ttl)
  end

  def mark_as_persisted
    @persisted = true
  end

  def mark_as_started
    @stopped = false
  end

  def resolve_dependencies
    @dependencies.each do |dependency|
      from = find_job(dependency[:from])
      to   = find_job(dependency[:to])

      to.incoming << dependency[:from]
      from.outgoing << dependency[:to]
    end
  end

  def dependencies_status
    resolve_dependencies
    @dependencies.each do |dependency|
      job = find_job(dependency[:from])
      dependency[:from_status] = job.friendly_status
      dependency[:ready] = job.ready_to_start?
      dependency[:parents_succeeded] = job.parents_succeeded?
    end
  end

  def find_job(name)
    match_data = /(?<klass>\w*[^-])-(?<identifier>.*)/.match(name.to_s)

    if match_data.nil?
      jobs.find { |node| node.klass.to_s == name.to_s }
    else
      jobs.find { |node| node.name.to_s == name.to_s }
    end
  end

  def finished?
    jobs.all?(&:finished?)
  end

  def started?
    !!started_at
  end

  def running?
    jobs_result = jobs.any?(&:running?)
    started? && !finished?
  end

  def failed?
    jobs.any?(&:failed?)
  end

  def stopped?
    stopped
  end

  def run(klass, opts = {})
    node = Herd::Runner.new( { klass: klass,
                                    transaction_id: opts[:xact_id],
                                    proxy_class: opts[:proxy_class],
                                    proxy_namespace: opts[:proxy_namespace] || "Herd",
                                    workflow_id: id,
                                    id: client.next_free_job_id(id, klass.to_s),
                                    params: opts.fetch(:params, {}),
                                    queue: opts[:queue],
                                    skip: opts[:skip] || false } )
    jobs << node
    proxies << node.proxy

    deps_after = [*opts[:after]]

    deps_after.each do |dep|
      @dependencies << { from: dep.to_s, to: node.name.to_s }
    end

    deps_before = [*opts[:before]]

    deps_before.each do |dep|
      @dependencies << { from: node.name.to_s, to: dep.to_s }
    end

    node.name
  end

  # this allows workflows to be referred to in the configurations
  def workflow( workflow, opts = {} )
    node = Herd::Runner.new( { workflow: workflow,
                                    transaction_id: opts[:xact_id],
                                    workflow_id: id,
                                    id: client.next_free_job_id(id, workflow.to_s),
                                    args: opts.fetch(:args, []) } )

    jobs << node

    deps_after = [*opts[:after]]

    deps_after.each do |dep|
      @dependencies << { from: dep.to_s, to: node.name.to_s }
    end

    deps_before = [*opts[:before]]

    deps_before.each do |dep|
      @dependencies << { from: node.name.to_s, to: dep.to_s }
    end

    node.name
  end

  def reload
    flow = self.class.find(id)

    self.jobs = flow.jobs
    self.proxies = flow.proxies
    self.stopped = flow.stopped

    self
  end

  def initial_jobs
    jobs.select(&:has_no_dependencies?)
  end

  def status
    if failed?
        :failed
      elsif running?
        :running
      elsif finished?
        :finished
      elsif stopped?
        :stopped
      else
        :running
    end
  end

  def started_at
    first_job&.started_at
  end

  def finished_at
    last_job&.finished_at
  end

  def status_hash
    jobs_arr = jobs.map { |j| [j.proxy.type, j.finished?, !j.failed?, j.proxy.done?, j.proxy.completed?] }
    to_hash.merge!( jobs: jobs_arr )
  end

  def to_hash
    # name = self.class.to_s
    {
      name: name,
      id: id,
      arguments: @arguments,
      total: jobs.count,
      finished: jobs.count(&:finished?),
      klass: name,
      status: status,
      stopped: stopped,
      started_at: started_at,
      finished_at: finished_at
    }
  end

  def name
    self.class.name
  end

  def to_json(options = {})
    Herd::JSON.encode(to_hash)
  end

  def self.descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end

  def id
    @id ||= client.next_free_workflow_id
  end

  def self.runner(&block)
    yield
  end

  def same_workflow_running?
    return false if parallel_workflows

    client.all_workflows.each do |flow|
      if flow.to_hash[:name] == name && flow.to_hash[:id] != id && flow.running?
        p flow.to_hash
        return true
      end
    end
    false
  end

  def skip?( klass )
    arguments[:skip_steps].include?
  end

  private

    def setup
      configure(*@arguments)
      resolve_dependencies
    end

    def client
      @client ||= Herd::Client.new
    end

    def first_job
      jobs.min_by { |n| n.started_at || Time.now.to_i }
    end

    def last_job
      jobs.max_by { |n| n.finished_at || 0 } if finished?
    end
end
