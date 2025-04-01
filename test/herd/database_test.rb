require 'test_helper'

module Herd::Test
  class DatabaseTest < TestCase
    def setup
      super
      @original_env = ENV.to_h
    end

    def teardown
      ENV.replace(@original_env)
      super
    end

    def test_default_database_configuration
      config = Herd::DatabaseConfig.config
      
      assert_equal 'postgresql', config[:adapter]
      assert_equal 'localhost', config[:host]
      assert_equal 5432, config[:port]
      assert_equal 'herd_development', config[:database]
      assert_equal ENV['USER'], config[:username]
      assert_nil config[:password]
      assert_equal 5, config[:pool]
      assert_equal 5000, config[:timeout]
      assert_equal 'prefer', config[:ssl_mode]
      assert_equal 'public', config[:schema_search_path]
      assert config[:reconnect]
      assert_equal 3, config[:retry_count]
      assert_equal 1, config[:retry_delay]
    end

    def test_custom_database_configuration
      custom_config = {
        host: 'custom-host',
        port: 5433,
        database: 'custom_db',
        username: 'custom_user',
        password: 'custom_password',
        pool: 10,
        timeout: 10000,
        ssl_mode: 'require',
        schema_search_path: 'custom_schema'
      }

      Herd::DatabaseConfig.configure(custom_config)
      config = Herd::DatabaseConfig.config

      assert_equal 'custom-host', config[:host]
      assert_equal 5433, config[:port]
      assert_equal 'custom_db', config[:database]
      assert_equal 'custom_user', config[:username]
      assert_equal 'custom_password', config[:password]
      assert_equal 10, config[:pool]
      assert_equal 10000, config[:timeout]
      assert_equal 'require', config[:ssl_mode]
      assert_equal 'custom_schema', config[:schema_search_path]
    end

    def test_database_configuration_from_env
      ENV['HERD_DB_HOST'] = 'env-host'
      ENV['HERD_DB_PORT'] = '5434'
      ENV['HERD_DB_NAME'] = 'env_db'
      ENV['HERD_DB_USER'] = 'env_user'
      ENV['HERD_DB_PASSWORD'] = 'env_password'
      ENV['HERD_DB_POOL'] = '15'
      ENV['HERD_DB_TIMEOUT'] = '15000'
      ENV['HERD_DB_SSL_MODE'] = 'verify-full'
      ENV['HERD_DB_SCHEMA'] = 'env_schema'

      config = Herd::DatabaseConfig.config

      assert_equal 'env-host', config[:host]
      assert_equal 5434, config[:port]
      assert_equal 'env_db', config[:database]
      assert_equal 'env_user', config[:username]
      assert_equal 'env_password', config[:password]
      assert_equal 15, config[:pool]
      assert_equal 15000, config[:timeout]
      assert_equal 'verify-full', config[:ssl_mode]
      assert_equal 'env_schema', config[:schema_search_path]
    end

    def test_database_connection_setup
      mock_connection = Minitest::Mock.new
      mock_connection.expect :execute, nil, [String]
      
      ActiveRecord::Base.stub :establish_connection, nil do
        ActiveRecord::Base.stub :connection_pool, OpenStruct.new(with_connection: -> { yield mock_connection }) do
          Herd::DatabaseConfig.configure
        end
      end

      mock_connection.verify
    end

    def test_database_connection_retry
      mock_connection = Minitest::Mock.new
      mock_connection.expect :execute, nil, [String]
      
      error = ActiveRecord::ConnectionNotEstablished.new("Connection failed")
      
      ActiveRecord::Base.stub :establish_connection, -> { raise error } do
        ActiveRecord::Base.stub :connection_pool, OpenStruct.new(with_connection: -> { yield mock_connection }) do
          assert_raises(RuntimeError) do
            Herd::DatabaseConfig.configure(retry_count: 1)
          end
        end
      end

      mock_connection.verify
    end

    def test_database_connection_success_after_retry
      mock_connection = Minitest::Mock.new
      mock_connection.expect :execute, nil, [String]
      
      error = ActiveRecord::ConnectionNotEstablished.new("Connection failed")
      attempts = 0
      
      ActiveRecord::Base.stub :establish_connection, -> { 
        attempts += 1
        raise error if attempts == 1
        nil
      } do
        ActiveRecord::Base.stub :connection_pool, OpenStruct.new(with_connection: -> { yield mock_connection }) do
          Herd::DatabaseConfig.configure(retry_count: 2)
        end
      end

      assert_equal 2, attempts
      mock_connection.verify
    end

    def test_database_schema_search_path
      mock_connection = Minitest::Mock.new
      mock_connection.expect :execute, nil, ["SET search_path TO custom_schema"]
      
      ActiveRecord::Base.stub :establish_connection, nil do
        ActiveRecord::Base.stub :connection_pool, OpenStruct.new(with_connection: -> { yield mock_connection }) do
          Herd::DatabaseConfig.configure(schema_search_path: 'custom_schema')
        end
      end

      mock_connection.verify
    end
  end
end 