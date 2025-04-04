# frozen_string_literal: true

module Herd
  class Configuration
    attr_accessor :concurrency, :namespace, :redis_url, :ttl, :locking_duration, :polling_interval, :herdfile, :database

    def self.from_json(json)
      new(Herd::Json.decode(json, symbolize_keys: true))
    end

    def initialize(**hash)
      self.concurrency      = hash.fetch(:concurrency, 5)
      self.namespace        = hash.fetch(:namespace, 'herd')
      self.redis_url        = hash.fetch(:redis_url, 'redis://localhost:6379/1')
      self.herdfile         = hash.fetch(:herdfile, 'Herdfile')
      self.ttl              = hash.fetch(:ttl, 3600 * 23.5)
      self.locking_duration = hash.fetch(:locking_duration, 2) # how long you want to wait for the lock to be released, in milliseconds
      self.polling_interval = hash.fetch(:polling_internal, 0.3) # how long the polling interval should be, in milliseconds
      @database = {
        adapter: ENV.fetch("DB_ADAPTER", "postgresql"),
        host: ENV.fetch("DB_HOST", "localhost"),
        port: ENV.fetch("DB_PORT", 5432),
        database: ENV.fetch("DB_NAME", "herd_development"),
        username: ENV.fetch("DB_USERNAME", "postgres"),
        password: ENV.fetch("DB_PASSWORD", "postgres")
      }
    end

    def herdfile=(path)
      @herdfile = Pathname(path)
    end

    def herdfile
      @herdfile.to_s if @herdfile.exist?
    end

    def to_hash
      {
        concurrency: concurrency,
        namespace: namespace,
        redis_url: redis_url,
        herdfile: herdfile,
        ttl: ttl,
        locking_duration: locking_duration,
        polling_interval: polling_interval,
        database: database
      }
    end

    def to_json
      Herd::Json.encode(to_hash)
    end
  end
end
