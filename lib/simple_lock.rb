# frozen_string_literal: true

require "digest"
require "ostruct"
require "redis"

Dir["./lib/initializers/*.rb"].sort.each { |f| require(f) }
Dir["./lib/simple_lock/*.rb"].sort.each { |f| require(f) }

module SimpleLock
  class Error < StandardError; end

  NO_SCRIPT_MAX_RETRIES = 1

  def self.client
    @client ||= SimpleLock::Redis.new(url: nil)
  end

  def self.client=(url)
    @client = SimpleLock::Redis.new(url: url)
  end

  def self.config
    @config ||= Config.new
  end

  def self.lock(key, ttl)
    key.prepend(config.key_prefix)

    locked = (config.retry_count + 1).times.any? do |attempt|
      sleep(backoff_for_attempt(attempt)) unless attempt.zero?

      safe_exec_script(SCRIPTS[:lock], [key], [ttl]) == "OK"
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
      client.script("load", script.raw)
    end
  end

  def self.safe_exec_script(script, ...)
    retries = 0

    begin
      client.evalsha(script.sha, ...)
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
