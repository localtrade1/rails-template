require "webmock/rspec"

# Disable all real network connections in tests. Allow loopback so Capybara /
# system tests still talk to the in-process Puma.
WebMock.disable_net_connect!(allow_localhost: true)
