# frozen_string_literal: true

require "bundler/setup"

require "graphviz"
require "hiredis"
require "pathname"
require "redis"
require "securerandom"
require "oj"

require "herd/json"
require "herd/cli"
require "herd/cli/overview"
require "herd/graph"
require "herd/client"
require "herd/configuration"
require "herd/workflow_not_found"
require "herd/dependency_level_too_deep"
require "herd/job"
require "herd/worker"
require "herd/workflow"

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
  end
end 