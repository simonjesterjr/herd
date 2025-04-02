# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "hiredis"
require "redis"
require "redlock"
require "sidekiq"
require "oj"
require "graphviz"
require "concurrent-ruby"
require "active_record"
require "active_support"

require_relative "support/database_helper"

# Add the lib directory to the load path
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

# Require all internal Herd files
require "herd/concerns/trackable"
require "herd/configuration"
require "herd/client"
require "herd/runner"
require "herd/graph"
require "herd/worker"
require "herd/workflow"
require "herd/json"
require "herd/database_setup"
require "herd/models/workflow"
require "herd/models/proxy"
require "herd/models/tracking"

require "herd"

# Configure test environment
Herd.configure do |config|
  config.redis_url = "redis://localhost:6379/1"
  config.herdfile = "test/fixtures/Herdfile"
  config.database = {
    adapter: 'postgresql',
    host: 'localhost',
    port: 5432,
    database: ENV.fetch('HERD_DB_NAME', 'herd_testing'),
    username: ENV.fetch('HERD_DB_USER', 'denaliai'),
    password: ENV.fetch('HERD_DB_PWD', 'denaliai'),
    pool: 5,
    timeout: 5000,
    schema_search_path: 'public'
  }
end

# Configure Sidekiq for testing
Sidekiq.configure_client do |config|
  config.redis = { url: "redis://localhost:6379/1" }
end

# Configure Oj for JSON parsing
Oj.default_options = { mode: :compat }

module Herd
  module Test
    class TestCase < Minitest::Test
      include Support::DatabaseHelper

      def setup
        super
        setup_redis
        setup_database
      end

      def teardown
        cleanup_redis
        cleanup_database
        super
      end

      private

      def setup_redis
        @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
        @redis.flushdb
      end

      def cleanup_redis
        @redis.flushdb
      end

      def setup_database
        Herd::DatabaseSetup.setup
      end

      def cleanup_database
        Herd::DatabaseSetup.teardown
      end

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

      def assert_match_array(expected, actual, msg = nil)
        msg = message(msg) { "Expected #{actual.inspect} to match array #{expected.inspect}" }
        assert_equal expected.sort, actual.sort, msg
      end

      def assert_not_nil(obj, msg = nil)
        msg = message(msg) { "Expected #{obj.inspect} to not be nil" }
        assert !obj.nil?, msg
      end
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
class TestProxy < Herd::Proxy
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

class FailedProxy < TestProxy
end