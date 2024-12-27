# frozen_string_literal: true

module SimpleLock
  class Redis
    attr_accessor :redis

    def initialize(redis = ::Redis.new)
      @redis = redis
    end

    delegate_missing_to :redis, allow_nil: false
  end
end
