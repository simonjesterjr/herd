# frozen_string_literal: true

class TestWorkflow < Herd::Workflow
  def configure(*args)
    run PrepareJob
    run NormalizeJob
    run FetchFirstJob
    run FetchSecondJob, after: FetchFirstJob
    run PersistFirstJob, after: FetchFirstJob
  end
end

class PrepareJob < Herd::Worker
  def perform
    # Test implementation
  end
end

class NormalizeJob < Herd::Worker
  def perform
    # Test implementation
  end
end

class FetchFirstJob < Herd::Worker
  def perform
    # Test implementation
  end
end

class FetchSecondJob < Herd::Worker
  def perform
    # Test implementation
  end
end

class PersistFirstJob < Herd::Worker
  def perform
    # Test implementation
  end
end 