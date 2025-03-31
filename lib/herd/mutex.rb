module Herd
  class Mutex
    attr_reader :configuration

    def initialize
      @configuration = client.configuration
    end

    def obtain_lock( key, duration = nil )
      val = duration.presence || configuration.locking_duration
      redlock_client.lock!( key, val ) do
        p "Herd Mutex Redlock obtained #{key} for #{val}"
        yield if block_given?
      end
    rescue Redlock::LockError => e
      raise e
    end

    private

      def redlock_client
        @redlock_client ||= begin
                              # servers = [ Herd::Client.redis_connection( Herd.configuration ) ]
                              Herd::Client.redis_connection( Herd.configuration ).with do |conn|
                                Redlock::Client.new(
                                  [conn],
                                  {
                                    retry_delay: configuration.polling_interval, # milliseconds
                                    retry_jitter: 50, # milliseconds
                                    redis_timeout: 0.50  # seconds
                                  }
                                )
                              end
                            end
      end

      def client
        @client ||= Herd::Client.new( Herd.configuration )
      end
  end
end
