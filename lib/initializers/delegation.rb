# frozen_string_literal: true

require "set"

module SimpleLock::Delegation
  class DelegationError < NoMethodError; end

  RUBY_RESERVED_KEYWORDS = %w[__ENCODING__ __LINE__ __FILE__ alias and BEGIN begin break
                              case class def defined? do else elsif END end ensure false for if in module next nil
                              not or redo rescue retry return self super then true undef unless until when while yield].freeze
  DELEGATION_RESERVED_KEYWORDS = %w[_ arg args block].freeze
  DELEGATION_RESERVED_METHOD_NAMES = Set.new(
    RUBY_RESERVED_KEYWORDS + DELEGATION_RESERVED_KEYWORDS
  ).freeze

  def delegate(*methods, to: nil, prefix: nil, allow_nil: nil, private: nil)
    unless to
      raise ArgumentError,
            "Delegation needs a target. Supply a keyword argument 'to' (e.g. delegate :hello, to: :greeter)."
    end

    if prefix == true && /^[^a-z_]/.match?(to)
      raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
    end

    method_prefix = \
      if prefix
        "#{prefix == true ? to : prefix}_"
      else
        ""
      end

    location = caller_locations(1, 1).first
    file = location.path
    line = location.lineno

    receiver = to.to_s
    receiver = "self.#{receiver}" if DELEGATION_RESERVED_METHOD_NAMES.include?(receiver)

    method_def = []
    method_names = []

    method_def << "self.private" if private

    methods.each do |method|
      method_name = prefix ? "#{method_prefix}#{method}" : method
      method_names << method_name.to_sym

      definition = \
        if /[^\]]=\z/.match?(method)
          "arg"
        else
          method_object =
            begin
              if to.is_a?(Module)
                to.method(method)
              elsif receiver == "self.class"
                method(method)
              end
            rescue NameError
              # Do nothing. Fall back to `"..."`
            end

          if method_object
            parameters = method_object.parameters

            if (parameters.map(&:first) & %i[opt rest keyreq key keyrest]).any?
              "..."
            else
              defn = parameters.filter_map { |type, arg| arg if type == :req }
              defn << "&block"
              defn.join(", ")
            end
          else
            "..."
          end
        end

      method = method.to_s
      if allow_nil

        method_def <<
          "def #{method_name}(#{definition})" \
          "  _ = #{receiver}" \
          "  if !_.nil? || nil.respond_to?(:#{method})" \
          "    _.#{method}(#{definition})" \
          "  end" \
          "end"
      else
        method_name = method_name.to_s

        method_def <<
          "def #{method_name}(#{definition})" \
          "  _ = #{receiver}" \
          "  _.#{method}(#{definition})" \
          "rescue NoMethodError => e" \
          "  if _.nil? && e.name == :#{method}" <<
          %(   raise DelegationError, "#{self}##{method_name} delegated to #{receiver}.#{method}, but #{receiver} is nil: \#{self.inspect}") <<
          "  else" \
          "    raise" \
          "  end" \
          "end"
      end
    end
    module_eval(method_def.join(";"), file, line)
    method_names
  end

  def delegate_missing_to(target, allow_nil: nil)
    target = target.to_s
    target = "self.#{target}" if DELEGATION_RESERVED_METHOD_NAMES.include?(target) || target == "__target"

    if allow_nil
      module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def respond_to_missing?(name, include_private = false)
          # It may look like an oversight, but we deliberately do not pass
          # +include_private+, because they do not get delegated.

          return false if name == :marshal_dump || name == :_dump
          #{target}.respond_to?(name) || super
        end

        def method_missing(method, *args, &block)
          __target = #{target}
          if __target.nil? && !nil.respond_to?(method)
            nil
          elsif __target.respond_to?(method)
            __target.public_send(method, *args, &block)
          else
            super
          end
        end
        ruby2_keywords(:method_missing)
      RUBY
    else
      module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def respond_to_missing?(name, include_private = false)
          # It may look like an oversight, but we deliberately do not pass
          # +include_private+, because they do not get delegated.

          return false if name == :marshal_dump || name == :_dump
          #{target}.respond_to?(name) || super
        end

        def method_missing(method, *args, &block)
          __target = #{target}
          if __target.nil? && !nil.respond_to?(method)
            raise DelegationError, "\#{method} delegated to #{target}, but #{target} is nil"
          elsif __target.respond_to?(method)
            __target.public_send(method, *args, &block)
          else
            super
          end
        end
        ruby2_keywords(:method_missing)
      RUBY
    end
  end
end
