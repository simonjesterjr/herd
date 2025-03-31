# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "hiredis"
require "redis"
require "sidekiq"
require "oj"
require "graphviz"

# Add the lib directory to the load path
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

# Require all internal Herd files
require "herd/configuration"
require "herd/client"
require "herd/runner"
require "herd/graph"
require "herd/worker"
require "herd/workflow"
require "herd/json"

require "herd"

# Configure test environment
Herd.configure do |config|
  config.redis_url = "redis://localhost:6379/1"
  config.herdfile = "test/fixtures/Herdfile"
end

# Configure Sidekiq for testing
Sidekiq.configure_client do |config|
  config.redis = { url: "redis://localhost:6379/1" }
end

# Configure Oj for JSON parsing
Oj.default_options = { mode: :compat }

# Base test case class
class Herd::TestCase < Minitest::Test
  def setup
    super
    @redis = Redis.new(url: "redis://localhost:6379/1")
    @redis.flushdb
  end

  def teardown
    super
    @redis.flushdb
  end

  private

  def assert_change(expected, &block)
    before = yield
    block.call
    after = yield
    assert_equal expected, after, "Expected #{expected.inspect}, got #{after.inspect}"
  end

  def assert_difference(expression, &block)
    b = block.binding
    exps = Array.wrap(expression)
    before = exps.map { |e| eval(e.to_s, b) }
    yield
    after = exps.map { |e| eval(e.to_s, b) }
    exps.each_with_index do |exp, i|
      error = "#{exp.inspect} didn't change by #{after[i] - before[i]}"
      assert_equal before[i] + 1, after[i], error
    end
  end
end

# Helper module for Array operations
module ArrayWrapping
  def self.wrap(object)
    if object.nil?
      []
    elsif object.respond_to?(:to_ary)
      object.to_ary || [object]
    else
      [object]
    end
  end
end

# Test partition classes
class TestPartition
  def self.create(parent_id: nil)
    new(parent_id)
  end

  def initialize(parent_id = nil)
    @id = SecureRandom.uuid
    @parent_id = parent_id
  end

  def id
    @id
  end

  def parent_id
    @parent_id
  end
end

class FailedPartition < TestPartition
end