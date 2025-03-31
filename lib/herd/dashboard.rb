module Herd
  class Dashboard < CLI::Overview

    attr_reader :workflow_id, :workflow

    def initialize( workflow_id )
      @workflow_id = workflow_id
      @workflow = client.find_workflow(workflow_id)
    end

    def current_state
      result = columns
      result.merge!( "Next Jobs": next_jobs )
    end

    def current_proxies
      [].tap do |proxies|
        currently_running do |job|
          proxies << job.proxy.reload
        end
      end
    end

    def jobs_by_type(type)
      sorted_jobs
    end

    private

      def client
        @client ||= Client.new
      end

      # todo
      # this is wrong .. it does not take into account
      # multiple precursor jobs
      def next_jobs
        [].tap do |jobs|
          currently_running do |job|
            job.outgoing.each { |o| jobs << o }
          end
        end.uniq
      end

      def currently_running
        return nil if workflow.finished?

        workflow.jobs.each do |job|
          next if job.finished? || job.failed?
          next unless job.enqueued?

          yield job
        end
      end
  end
end
