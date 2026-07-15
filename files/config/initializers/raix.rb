require "faraday"
require "faraday/retry"

retry_options = {
  max: 3,
  interval: 1,
  backoff_factor: 2,
  exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [ Faraday::ServerError ]
}

openrouter_api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openrouter, :api_key)

Raix.configure do |config|
  if openrouter_api_key.present?
    config.openrouter_client = OpenRouter::Client.new(access_token: openrouter_api_key) do |c|
      c.faraday do |f|
        f.request :retry, retry_options
        f.response :logger, ::Logger.new($stdout), { headers: true, bodies: true, errors: true } do |logger|
          logger.filter(/(Bearer) (\S+)/, '\1[REDACTED]')
        end
      end
    end
  end
end
