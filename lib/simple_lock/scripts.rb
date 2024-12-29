# frozen_string_literal: true

module SimpleLock
  Script = Struct.new(:raw) do
    def sha
      @sha ||= Digest::SHA1.hexdigest(raw)
    end
  end

  LOCK_VALUE = "1"

  SCRIPTS = {
    lock: Script.new("return redis.call('set', KEYS[1], #{LOCK_VALUE}, 'NX', 'PX', ARGV[1])"),
    unlock: Script.new("redis.call('del', KEYS[1])")
  }.freeze
end
