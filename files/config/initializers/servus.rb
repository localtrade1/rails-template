# frozen_string_literal: true

Servus::Base.extend(Dry::Initializer)

# Class-level bang convenience for jobs/controllers. Matches the semantics of
# the instance-level call!: raise on failure, return the success data directly.
Servus::Base.singleton_class.class_eval do
  def call!(**args)
    result = call(**args)
    raise result.error unless result.success?
    result.data
  end
end

if Rails.env.development?
  Rails.application.config.to_prepare do
    Servus::Support::Validator.clear_cache! if defined?(Servus::Support::Validator)
  end
end
