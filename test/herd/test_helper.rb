# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "herd"

class Herd::TestCase < Minitest::Test
  def setup
    super
    Herd.configure do |config|
      config.redis_url = "redis://localhost:6379/1"
      config.herdfile = "test/fixtures/Herdfile"
      config.concurrency = 5
      config.namespace = "herd"
      config.locking_duration = 2
      config.polling_interval = 0.3
    end
  end

  def teardown
    super
    Herd.configuration = nil
  end

  # Helper methods for testing
  def assert_change(exp, message = nil)
    before = yield
    result = yield
    assert_equal exp, result, message
  end

  def assert_not_nil(exp, message = nil)
    refute_nil exp, message
  end

  def assert_empty(exp, message = nil)
    assert exp.empty?, message
  end

  def assert_not_empty(exp, message = nil)
    refute exp.empty?, message
  end

  def assert_truthy(exp, message = nil)
    assert exp, message
  end

  def assert_falsy(exp, message = nil)
    refute exp, message
  end

  def assert_match_array(exp, act, message = nil)
    assert_equal exp.sort, act.sort, message
  end
end 