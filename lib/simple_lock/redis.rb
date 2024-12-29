# frozen_string_literal: true

module SimpleLock
  class Redis
    def initialize(url: nil)
      @redis = ::Redis.new(url: url)
    end

    delegate_missing_to :@redis, allow_nil: false
  end
end
