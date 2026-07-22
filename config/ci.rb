# frozen_string_literal: true

DEVELOPMENT_ENV = "set -a; if [ -f .env ]; then . ./.env; fi; set +a"
TEST_ENV = "set -a; if [ -f .env.test ]; then . ./.env.test; elif [ -f .env ]; then . ./.env; fi; set +a"

CI.run do
  step "Setup", "#{DEVELOPMENT_ENV}; bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop --parallel"
  step "Style: ERuby", "bin/erblint -la"

  step "Specs: Rspec", "#{TEST_ENV}; bin/rspec spec/models/ spec/concerns spec/requests"

  step "Security: Gem audit", "bin/bundler-audit --update"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
