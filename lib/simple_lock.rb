# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"

require "digest"
require "ostruct"
require "redis"

Dir["./lib/simple_lock/*.rb"].sort.each { |f| require(f) }

module SimpleLock
  class Error < StandardError; end

  NO_SCRIPT_MAX_RETRIES = 1

  def self.redis
    @redis ||= SimpleLock::Redis.new
  end

  def self.redis=(redis)
    @redis = SimpleLock::Redis.new(redis)
  end

  def self.config
    @config ||= Config.new
  end

  # @param [String] key
  # @param [Integer] ttl
  # @return [Class<StandardError>, TrueClass, FalseClass]
  def self.lock(key, ttl)
    key.prepend(config.key_prefix)

    locked = (config.retry_count + 1).times.any? do |attempt|
      sleep(backoff_for_attempt(attempt)) unless attempt.zero?

      safe_exec_script(SCRIPTS[:lock], [key], ["true", ttl]).present?
    end

    return locked unless block_given?

    begin
      yield(locked)
    ensure
      unlock(key) if locked
    end
  end

  def self.unlock(key)
    key.prepend(config.key_prefix)

    safe_exec_script(SCRIPTS[:unlock], [key])
  rescue StandardError
    # Nothing to do, this is just a best-effort attempt.
  end

  def self.load_scripts
    SCRIPTS.each_value do |script|
      redis.script("load", script.raw)
    end
  end

  def self.safe_exec_script(script, ...)
    retries = 0

    begin
      redis.evalsha(script.sha, ...)
    rescue ::Redis::CommandError => e
      if e.message.include?("NOSCRIPT") && (retries += 1) <= NO_SCRIPT_MAX_RETRIES
        load_scripts
        retry
      end

      raise Error, e.message
    end
  end

  def self.backoff_for_attempt(attempt)
    delay = config.retry_proc.respond_to?(:call) ? config.retry_proc.call(attempt) : config.retry_delay

    (delay + rand(config.retry_jitter)).fdiv(1000)
  end
end
