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
require "herd/cli"
require "herd/cli/overview"
require "herd/graph"
require "herd/client"
require "herd/configuration"
require "herd/proxy"
require "herd/workflow_not_found"
require "herd/dependency_level_too_deep"
require "herd/job"
require "herd/worker"
require "herd/workflow"
require "herd/version"
require "herd/database_config"
require "herd/models/workflow"
require "herd/models/proxy"
require "herd/models/tracking"

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
    yield configuration
    setup_database
  end

  private

  def self.setup_database
    DatabaseConfig.configure(configuration.database)
  end

  class Configuration
    attr_accessor :redis_url, :database

    def initialize
      @redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/1'
      @database = {}
    end
  end
end 