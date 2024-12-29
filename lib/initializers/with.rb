# frozen_string_literal: true

module SimpleLock
  module With
    def with(**attributes)
      old_values = {}
      begin
        attributes.each do |key, value|
          old_values[key] = public_send(key)
          public_send("#{key}=", value)
        end
        yield self
      ensure
        old_values.each do |key, old_value|
          public_send("#{key}=", old_value)
        end
      end
    end
  end
end
