# frozen_string_literal: true

require "bundler/setup"

require "graphviz"
require "hiredis"
require "pathname"
require "redis"
require "securerandom"
require "oj"
require 'active_record'
require 'sidekiq'
require 'json'

require "herd/json"
require "herd/concerns/trackable"
require "herd/configuration"
require "herd/configuration_error"
require "herd/database_config"
require "herd/database_setup"
require "herd/invalid_dependency_error"
require "herd/duplicate_job_error"
require "herd/workflow_not_found"
require "herd/dependency_level_too_deep"
require "herd/invalid_job_id_error"
require "herd/invalid_job_name_error"
require "herd/invalid_job_class_error"
require "herd/invalid_workflow_state_error"
require "herd/invalid_workflow_configuration_error"
require "herd/models/workflow"
require "herd/models/proxy"
require "herd/models/tracking"
require "herd/workflow"
require "herd/job"
require "herd/worker"
require "herd/client"
require "herd/runner"
require "herd/graph"
require "herd/cli"
require "herd/cli/overview"
require "herd/version"

module Herd
  def self.herdfile
    configuration.herdfile
  end

  def self.root
    Pathname.new(__FILE__).parent.parent
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
    setup_database
    configuration
  end

  private

    def self.setup_database
      Herd::DatabaseConfig.configure(configuration.database)
    end

end 
