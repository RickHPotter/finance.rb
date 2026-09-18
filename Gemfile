# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.7"
gem "rails"

gem "activerecord-import"
gem "bootsnap", require: false
gem "jsbundling-rails"
gem "paper_trail"
gem "pg"
gem "propshaft"
gem "puma"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"

gem "image_processing"
gem "ruby-vips", require: false

# UI
gem "phlex-rails"
gem "tailwind_merge"

# Authentication
gem "devise"
gem "letter_opener_web"

# CD
gem "dockerfile-rails"
gem "dotenv-rails"
gem "kamal", require: false

# EXCEL
gem "csv"
gem "roo"
gem "write_xlsx"

# PWA
gem "web-push"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

gem "json", "< 3.0"

group :development, :test do
  gem "bullet"
  gem "debug", platforms: %i[mri windows]
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails"
end

group :development do
  gem "annotaterb"
  gem "awesome_print"
  gem "brakeman"
  gem "bundler-audit"
  gem "erb_lint", require: false
  gem "guard-rspec", require: false
  gem "hotwire-spark"
  gem "rails-erd"
  gem "rubocop-rails-omakase", require: false
  gem "ruby_ui", require: false
  gem "web-console"

  # NEOVIM IDE
  gem "neovim"
  gem "solargraph"
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "webmock"
end

group :production do
  gem "appsignal"
end
