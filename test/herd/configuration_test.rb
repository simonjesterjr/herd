# frozen_string_literal: true

require "test_helper"

class Herd::ConfigurationTest < Herd::TestCase
  def test_has_defaults_set
    config = Herd::Configuration.new
    config.herdfile = "test/fixtures/Herdfile"
    
    assert_equal "redis://localhost:6379/1", config.redis_url
    assert_equal 5, config.concurrency
    assert_equal "herd", config.namespace
    assert_equal "test/fixtures/Herdfile", config.herdfile
    assert_equal 2, config.locking_duration
    assert_equal 0.3, config.polling_interval
  end

  def test_configure_allows_setting_options_through_block
    Herd.configure do |config|
      config.redis_url = "redis://localhost:6379/1"
      config.concurrency = 25
      config.locking_duration = 5
      config.polling_interval = 0.5
    end

    assert_equal "redis://localhost:6379/1", Herd.configuration.redis_url
    assert_equal 25, Herd.configuration.concurrency
    assert_equal 5, Herd.configuration.locking_duration
    assert_equal 0.5, Herd.configuration.polling_interval
  end
end 