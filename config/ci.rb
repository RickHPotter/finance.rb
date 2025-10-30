# frozen_string_literal: true

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop --parallel"
  step "Style: ERuby", "bin/erblint -la"

  step "Specs: Rspec", "bin/rspec spec/models/ spec/concerns spec/requests"

  step "Security: Gem audit", "bin/bundler-audit --update"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
