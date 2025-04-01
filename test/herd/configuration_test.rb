# frozen_string_literal: true

require "test_helper"

class Herd::ConfigurationTest < Herd::TestCase
  def setup
    super
    @config = Herd::Configuration.new
  end

  def test_configuration_initializes_with_default_values
    assert_nil @config.herdfile
    assert_nil @config.redis_url
    assert_nil @config.database_url
    assert_nil @config.logger
    assert_equal :info, @config.log_level
    assert_equal 30, @config.job_timeout
    assert_equal 5, @config.max_retries
    assert_equal 60, @config.retry_delay
    assert_equal 3600, @config.workflow_timeout
    assert_equal 86400, @config.workflow_expiry
    assert_equal 300, @config.cleanup_interval
    assert_equal 1000, @config.batch_size
    assert_equal false, @config.enable_tracking
    assert_equal false, @config.enable_metrics
    assert_equal false, @config.enable_audit_log
  end

  def test_configuration_loads_from_yaml
    config = Herd::Configuration.new(
      herdfile: "test/fixtures/config.yml"
    )
    
    assert_equal "redis://localhost:6379/1", config.redis_url
    assert_equal "postgresql://localhost:5432/herd", config.database_url
    assert_equal :debug, config.log_level
    assert_equal 60, config.job_timeout
    assert_equal 10, config.max_retries
    assert_equal 120, config.retry_delay
    assert_equal 7200, config.workflow_timeout
    assert_equal 172800, config.workflow_expiry
    assert_equal 600, config.cleanup_interval
    assert_equal 2000, config.batch_size
    assert_equal true, config.enable_tracking
    assert_equal true, config.enable_metrics
    assert_equal true, config.enable_audit_log
  end

  def test_configuration_validates_required_settings
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        redis_url: nil,
        database_url: nil
      )
    end
  end

  def test_configuration_validates_urls
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        redis_url: "invalid-url",
        database_url: "invalid-url"
      )
    end
  end

  def test_configuration_validates_timeouts
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        job_timeout: -1,
        workflow_timeout: -1,
        workflow_expiry: -1
      )
    end
  end

  def test_configuration_validates_retries
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        max_retries: -1,
        retry_delay: -1
      )
    end
  end

  def test_configuration_validates_batch_size
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        batch_size: 0
      )
    end
  end

  def test_configuration_validates_log_level
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        log_level: :invalid_level
      )
    end
  end

  def test_configuration_validates_cleanup_interval
    assert_raises(Herd::ConfigurationError) do
      Herd::Configuration.new(
        cleanup_interval: 0
      )
    end
  end

  def test_configuration_merges_with_defaults
    config = Herd::Configuration.new(
      redis_url: "redis://localhost:6379/1",
      database_url: "postgresql://localhost:5432/herd",
      log_level: :debug
    )

    assert_equal "redis://localhost:6379/1", config.redis_url
    assert_equal "postgresql://localhost:5432/herd", config.database_url
    assert_equal :debug, config.log_level
    assert_equal 30, config.job_timeout # Default value
    assert_equal 5, config.max_retries # Default value
  end

  def test_configuration_to_hash
    config = Herd::Configuration.new(
      redis_url: "redis://localhost:6379/1",
      database_url: "postgresql://localhost:5432/herd",
      log_level: :debug
    )

    hash = config.to_hash
    assert_equal "redis://localhost:6379/1", hash[:redis_url]
    assert_equal "postgresql://localhost:5432/herd", hash[:database_url]
    assert_equal :debug, hash[:log_level]
    assert_equal 30, hash[:job_timeout]
    assert_equal 5, hash[:max_retries]
  end

  def test_configuration_from_hash
    hash = {
      redis_url: "redis://localhost:6379/1",
      database_url: "postgresql://localhost:5432/herd",
      log_level: :debug,
      job_timeout: 60,
      max_retries: 10
    }

    config = Herd::Configuration.from_hash(hash)
    assert_equal "redis://localhost:6379/1", config.redis_url
    assert_equal "postgresql://localhost:5432/herd", config.database_url
    assert_equal :debug, config.log_level
    assert_equal 60, config.job_timeout
    assert_equal 10, config.max_retries
  end

  def test_configuration_environment_specific
    ENV["HERD_ENV"] = "test"
    config = Herd::Configuration.new(
      herdfile: "test/fixtures/config.yml"
    )

    assert_equal "redis://localhost:6379/1", config.redis_url
    assert_equal "postgresql://localhost:5432/herd_test", config.database_url
  end

  def test_configuration_development_specific
    ENV["HERD_ENV"] = "development"
    config = Herd::Configuration.new(
      herdfile: "test/fixtures/config.yml"
    )

    assert_equal "redis://localhost:6379/1", config.redis_url
    assert_equal "postgresql://localhost:5432/herd_development", config.database_url
  end

  def test_configuration_production_specific
    ENV["HERD_ENV"] = "production"
    config = Herd::Configuration.new(
      herdfile: "test/fixtures/config.yml"
    )

    assert_equal "redis://redis.production:6379/1", config.redis_url
    assert_equal "postgresql://db.production:5432/herd_production", config.database_url
  end

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