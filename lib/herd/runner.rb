# frozen_string_literal: true

module Herd
  class Runner
    attr_accessor :workflow_id, :incoming, :outgoing, :params,
                  :finished_at, :failed_at, :started_at, :enqueued_at,
                  :payloads

    attr_reader :klass, :transaction_id, :workflow_id,
                :id, :params, :queue, :proxy_class, :proxy_namespace,
                :workflow, :args, :output_payload

    def initialize( opts = {} )
      options = opts.dup
      assign_variables(options)
    end

    def name
      @name ||= "#{klass}|#{id}"
    end

    def to_json(options = {} )
      Herd::JSON.encode(as_json)
    end

    def self.from_hash(hash)
      Herd::Runner.new( hash )
    end

    def output(data)
      @output_payload = data
    end

    def proxy
      Object.const_get( proxy_class ).find_or_create_by( parent_id: transaction_id )
    end

    def start!
      @started_at = current_timestamp
      @failed_at = nil
      proxy.in_process!
    end

    def enqueue!
      @enqueued_at = current_timestamp
      @started_at = nil
      @finished_at = nil
      @failed_at = nil
      proxy.partitioned!
    end

    def finish!
      proxy.done! unless proxy.done?
      @finished_at = current_timestamp
    end

    def finished?
      !finished_at.nil? && proxy.completed?
    end

    def fail!
      @finished_at = @failed_at = current_timestamp
      proxy.errored!
    end

    def enqueued?
      !enqueued_at.nil?
    end

    def failed?
      return !failed_at.nil? && proxy.failed? if proxy

      !failed_at.nil?
    end

    def succeeded?
      finished? && !failed? && proxy.completed?
    end

    def started?
      return !started_at.nil? && proxy.in_process? if proxy

      !started_at.nil?
    end

    def running?
      started? && !finished? && proxy.running?
    end

    def friendly_status
      case
        when failed?
          :failed
        when running?
          :running
        when finished?
          :finished
        else
          :running
      end
    end

    def ready_to_start?
      !running? && !enqueued? && !finished? && !failed? && parents_succeeded?
    end

    def parents_succeeded?
      incoming.none? do |name|
        !client.find_job(workflow_id, name).succeeded?
      end
    end

    def has_no_dependencies?
      incoming.empty?
    end

    def as_json
      {
        id: id,
        klass: klass.to_s,
        queue: queue,
        incoming: incoming,
        outgoing: outgoing,
        finished_at: finished_at,
        enqueued_at: enqueued_at,
        started_at: started_at,
        failed_at: failed_at,
        params: params,
        workflow_id: workflow_id,
        output_payload: output_payload,
        workflow: workflow,
        transaction_id: transaction_id,
        proxy_class: proxy_class,
        args: args
      }
    end

    def as_node
      {
        name: klass.to_s,
        state: finished?,
        incoming: incoming,
        outgoing: outgoing
      }
    end

    private

      def client
        @client ||= Client.new
      end

      def current_timestamp
        Time.now.utc.to_i
      end

      def assign_variables(opts)
        @id             = opts[:id]
        @klass          = opts[:klass] || self.class
        @queue          = opts[:queue] || 'herd'
        @incoming       = opts[:incoming] || []
        @outgoing       = opts[:outgoing] || []
        @finished_at    = opts[:finished_at]
        @started_at     = opts[:started_at]
        @enqueued_at    = opts[:enqueued_at]
        @failed_at      = opts[:failed_at]
        @params         = opts[:params] || {}
        @output_payload = opts[:output_payload]
        @workflow_id    = opts[:workflow_id]
        @workflow       = opts[:workflow]
        @transaction_id = opts[:transaction_id]
        @worker_namespace = opts[:worker_namespace] ? "#{opts[:worker_namespace]}::" : ""
        @proxy_namespace = opts[:proxy_namespace] || "Herd"
        @proxy_class    = opts[:proxy_class] || "Proxy"
        @args           = opts[:args] || []
      end

    def self.enqueue!(job)
      job.enqueued_at = current_timestamp
      job.save
    end

    def self.perform!(job)
      job.started_at = current_timestamp
      job.save
      job.perform
      job.finished_at = current_timestamp
      job.save
    end

    def self.fail!(job, error)
      job.failed_at = current_timestamp
      job.error = error
      job.save
    end
  end
end
