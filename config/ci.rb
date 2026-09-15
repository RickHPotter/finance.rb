# frozen_string_literal: true

DEVELOPMENT_ENV = "set -a; if [ -f .env ]; then . ./.env; fi; set +a"
TEST_ENV = "set -a; if [ -f .env.test ]; then . ./.env.test; elif [ -f .env ]; then . ./.env; fi; set +a"

CI.run do
  step "Setup", "#{DEVELOPMENT_ENV}; bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop --parallel"
  step "Style: ERuby", "bin/erblint -la"

  step "Specs: Fast", "#{TEST_ENV}; COVERAGE=true COVERAGE_RESET=true COVERAGE_COMMAND_NAME=rspec-fast RSPEC_PROFILE_PATH=tmp/ci-rspec-fast.json bin/specs fast"
  step "Specs: Feature", "#{TEST_ENV}; COVERAGE=true COVERAGE_COMMAND_NAME=rspec-feature RSPEC_PROFILE_PATH=tmp/ci-rspec-feature.json bin/specs feature"
  step "Specs: Operational", "#{TEST_ENV}; COVERAGE=true COVERAGE_COMMAND_NAME=rspec-operational RSPEC_PROFILE_PATH=tmp/ci-rspec-operational.json bin/specs operational"
  step "Specs: JavaScript", "node --test spec/javascript/*_test.mjs"

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
