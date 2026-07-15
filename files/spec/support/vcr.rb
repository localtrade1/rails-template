require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [ :method, :uri, :body ]
  }

  # Strip secrets from recorded interactions
  %w[
    MACHINA_SERVICE_TOKEN
    OPENROUTER_API_KEY
    SENTRY_DSN
  ].each do |var|
    config.filter_sensitive_data("<#{var}>") { ENV[var] }
  end

  config.filter_sensitive_data("<AUTHORIZATION>") do |interaction|
    interaction.request.headers["Authorization"]&.first
  end
end
