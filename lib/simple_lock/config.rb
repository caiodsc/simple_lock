# frozen_string_literal: true

module SimpleLock
  class Config
    attr_accessor :config

    DEFAULT_CONFIG = OpenStruct.new(
      {
        retry_count: 3,
        retry_delay: 200,
        retry_jitter: 50,
        retry_proc: nil,
        key_prefix: "simple_lock:"
      }
    )

    def initialize
      @config = DEFAULT_CONFIG
    end

    delegate_missing_to :config, allow_nil: false

    def respond_to_missing?(method_name, ...)
      DEFAULT_CONFIG.table.keys.include?(method_name.to_s.delete_suffix("=").to_sym)
    end
  end
end
