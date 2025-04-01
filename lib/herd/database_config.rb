module Herd
  module DatabaseConfig
    class << self
      def configure(config = {})
        @config = default_config.merge(config)
        setup_connection
      end

      def config
        @config ||= default_config
      end

      private

      def default_config
        {
          adapter: 'postgresql',
          host: ENV['HERD_DB_HOST'] || 'localhost',
          port: ENV['HERD_DB_PORT'] || 5432,
          database: ENV['HERD_DB_NAME'] || 'herd_development',
          username: ENV['HERD_DB_USER'] || ENV['USER'],
          password: ENV['HERD_DB_PASSWORD'],
          pool: ENV['HERD_DB_POOL'] || 5,
          timeout: ENV['HERD_DB_TIMEOUT'] || 5000,
          ssl_mode: ENV['HERD_DB_SSL_MODE'] || 'prefer',
          schema_search_path: ENV['HERD_DB_SCHEMA'] || 'public',
          reconnect: true,
          retry_count: 3,
          retry_delay: 1
        }
      end

      def setup_connection
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.connection.execute("SET search_path TO #{config[:schema_search_path]}")
        end
      rescue ActiveRecord::ConnectionNotEstablished => e
        retry_connection(e)
      end

      def retry_connection(error, attempt = 1)
        if attempt <= config[:retry_count]
          sleep(config[:retry_delay])
          setup_connection
        else
          raise "Failed to establish database connection after #{config[:retry_count]} attempts: #{error.message}"
        end
      end
    end
  end
end 