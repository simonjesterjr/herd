# frozen_string_literal: true

# Test workflow class
class TestWorkflow < Herd::Workflow
  def configure
    run PrepareJob
    run FetchFirstJob, after: PrepareJob
    run FetchSecondJob, after: PrepareJob
    run NormalizeJob, after: [FetchFirstJob, FetchSecondJob]
    run PersistFirstJob, after: NormalizeJob
  end
end

# Test job classes
class PrepareJob < Herd::Worker
  def perform(workflow_id)
    setup_job("Prepare")
    mark_as_finished
  end
end

class FetchFirstJob < Herd::Worker
  def perform(workflow_id)
    setup_job("FetchFirstJob")
    mark_as_finished
  end
end

class FetchSecondJob < Herd::Worker
  def perform(workflow_id)
    setup_job("FetchSecondJob")
    mark_as_finished
  end
end

class NormalizeJob < Herd::Worker
  def perform(workflow_id)
    setup_job("NormalizeJob")
    mark_as_finished
  end
end

class PersistFirstJob < Herd::Worker
  def perform(workflow_id)
    setup_job("PersistFirstJob")
    mark_as_finished
  end
end 