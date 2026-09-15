# frozen_string_literal: true

require "webmock/rspec"

# Stubbed requests remain available, while Capybara's in-process server and local
# Selenium traffic can still communicate over loopback.
WebMock.disable_net_connect!(allow_localhost: true)
