# frozen_string_literal: true

require 'active_record'

module Herd
  module DatabaseSetup
    class << self
      def setup(config = Herd.configuration.database)
        return if ActiveRecord::Base.connected?

        config = config.merge(
          database: ENV.fetch('HERD_DB_NAME', config[:database]),
          username: ENV.fetch('HERD_DB_USER', config[:username]),
          password: ENV.fetch('HERD_DB_PWD', config[:password])
        )

        ActiveRecord::Base.establish_connection(config)
        run_migrations
      rescue ActiveRecord::NoDatabaseError
        create_database(config)
        run_migrations
      end

      def teardown
        ActiveRecord::Base.remove_connection
      end

      private

      def run_migrations
        migration_paths = [File.expand_path('../../../lib/herd/migrations', __FILE__)]
        ActiveRecord::Migration.verbose = false
        ActiveRecord::MigrationContext.new(migration_paths).migrate
      end

      def create_database(config)
        postgres_config = config.merge(database: 'postgres')
        ActiveRecord::Base.establish_connection(postgres_config)
        
        # Check if database exists
        unless database_exists?(config[:database])
          ActiveRecord::Base.connection.create_database(config[:database])
        end
        
        ActiveRecord::Base.establish_connection(config)
      end

      def database_exists?(database_name)
        ActiveRecord::Base.connection.execute(
          "SELECT 1 FROM pg_database WHERE datname = '#{database_name}'"
        ).any?
      end
    end
  end
end 