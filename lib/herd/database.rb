# frozen_string_literal: true

module Herd
  module Database
    class << self
      def establish_connection(config = Herd.configuration)
        ActiveRecord::Base.establish_connection(config.database_config)
      end

      def connected?
        ActiveRecord::Base.connected?
      end

      def disconnect!
        ActiveRecord::Base.disconnect!
      end
    end
  end
end 