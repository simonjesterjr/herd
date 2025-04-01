# frozen_string_literal: true

module Herd
  module DatabaseSetup
    class << self
      def setup(config = Herd.configuration)
        return if Database.connected?

        Database.establish_connection(config)
        run_migrations
      end

      def teardown
        Database.disconnect!
      end

      private

      def run_migrations
        ActiveRecord::Base.connection.migration_context.migrate
      rescue ActiveRecord::NoDatabaseError
        create_database
        run_migrations
      end

      def create_database
        config = Herd.configuration.database_config
        ActiveRecord::Base.establish_connection(config.merge(database: 'postgres'))
        ActiveRecord::Base.connection.create_database(config[:database])
        ActiveRecord::Base.establish_connection(config)
      end
    end
  end
end 