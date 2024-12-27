# frozen_string_literal: true

module SimpleLock
  Script = Struct.new(:raw) do
    def sha
      Digest::SHA1.hexdigest(raw)
    end
  end

  SCRIPTS = {
    lock: Script.new('return redis.call("set", KEYS[1], ARGV[1], "NX", "PX", ARGV[2])'),
    unlock: Script.new('redis.call("del", KEYS[1])')
  }.freeze
end
