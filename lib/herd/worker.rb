# frozen_string_literal: true

require 'sidekiq'

class Herd::Worker
  attr_accessor :client, :workflow_id, :job,
                :configuration, :proxy

  include Sidekiq::Worker
  sidekiq_options retry: 0
  sidekiq_options queue: 'herd'

  def failed?
    job.failed?
  end

  # this mimics first part of herd method
  def setup( workflow_id )
    @workflow_id = workflow_id
    @partition_id = workflow.arguments[0]
    setup_job( self.class.name )
    job.payloads = incoming_payloads
    mark_as_started
  end

  # the last part of herd method
  def teardown
    mark_as_finished
    enqueue_outgoing_jobs
  end

  def herd(workflow_id, job_id)
    @workflow_id = workflow_id
    @partition_id = workflow.arguments[0]
    setup_job( job_id )

    if job.succeeded?
      # Try to enqueue outgoing jobs again because the last job has mutex redlock error
      enqueue_outgoing_jobs
      return
    end

    job.payloads = incoming_payloads
    mark_as_started

    begin
      yield
    rescue StandardError => e
      mark_as_failed
      raise e
    else
      mark_as_finished
      enqueue_outgoing_jobs
    end
  end

  def herd_parent_notify( parent_proxy_id, proxy_id = nil )
    @workflow_id = transaction.target_uuid
    @partition_id = transaction.id
    setup_job( parent_proxy.migration_job )
    mark_as_finished
    enqueue_outgoing_jobs

    if proxy.present?
      parent_proxy.add_note("next queued (#{proxy.id})")
    else
      parent_proxy.add_note("next queued!")
    end
  rescue StandardError => e
    parent_proxy.update( error: e )
  end

  private

    def client
      @client ||= Herd::Client.new( Herd.configuration )
    end

    def configuration
      @configuration ||= client.configuration
    end

    def setup_job( job_id )
      @job ||= workflow.find_job( job_id )
    end

    def workflow
      @workflow ||= client.find_workflow( @workflow_id )
    end

    def incoming_payloads
      job.incoming.map do |job_name|
        job = client.find_job(workflow_id, job_name)
        {
          id: job.name,
          class: job.klass.to_s,
          output: job.output_payload
        }
      end
    end

    def mark_as_finished
      mutex = Herd::Mutex.new
      count ||= 0
      key = "herd_finish_#{job.name}"
      mutex.obtain_lock( key ) do
        job.finish!
        client.persist_job(workflow_id, job)
      end

      return unless workflow.finished?

      # only run in conjunction with a finalizing worker
      partition = Migration::Partition.find( job.transaction_id )
      partition.add_note( "Workflow FINISHED #{Time.current}" )
      partition.done!
    rescue Redlock::LockError => e
      context = {
        class: self.class.name,
        count: count,
        failure: false
      }

      Honeybadger.notify( e, context: context ) if (count % 5).zero? || count == 2 || count == 1 || count == 28 || count == 29

      sleep 2
      count += 1
      retry if count < 30

      Honeybadger.notify( e,
                          context: {
                            class: self.class.name,
                            count: count,
                            failure: true
                          } )
    end

    def mark_as_failed
      job.fail!
      client.persist_job(workflow_id, job)
    end

    def mark_as_started
      job.start!
      client.persist_job(workflow_id, job)
    end

    def proxy
      @proxy ||= @job.proxy_class.find_by( parent_id: runner.transaction_id )
    end

    def transaction
      proxy.parent
    end

    def proxy_is_child?
      proxy.parent_id != runner.proxy.parent_id
    end

    def elapsed(start)
      ( Time.zone.now - start ).to_f.round(3)
    end

    def enqueue_outgoing_jobs
      mutex = Herd::Mutex.new
      count ||= 0
      job.outgoing.each do |job_name|
        key = "herd_next_#{job_name}"
        mutex.obtain_lock( key ) do
          out = client.find_job( workflow_id, job_name )
          if out.ready_to_start?
            client.enqueue_job( workflow_id, out )
          else
            e = Exceptions::MigrationException.new( "Job #{job_name} is not ready to start" )
            if count > 28
              Honeybadger.notify( e,
                                  context: {
                                    class: self.class.name,
                                    count: count,
                                    failure: false,
                                    running: out.running?,
                                    enqueued: out.enqueued?,
                                    finished: out.finished?,
                                    failed: out.failed?,
                                    parents: out.parents_succeeded?
                                  } )
              raise e
            end
          end
        end
      end
    rescue Redlock::LockError => e
      context = {
        class: self.class.name,
        count: count,
        failure: false,
        sleep: configuration.polling_interval,
        block: configuration.locking_duration
      }

      # Honeybadger.notify( e, context: context ) if (count % 5).zero? || count == 2 || count == 1 || count == 28 || count == 29

      sleep rand / 100
      count += 1
      retry if count < 30

      Honeybadger.notify( e,
                          context: {
                            class: self.class.name,
                            count: count,
                            failure: true,
                            sleep: configuration.polling_interval,
                            block: configuration.locking_duration
                          } )
    rescue Exceptions::MigrationException
      count += 1
      retry if count < 30
    end
end
