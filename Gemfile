# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.1"
gem "rails", "~> 8.0"

gem "activerecord-import"
gem "bootsnap", require: false
gem "jbuilder"
gem "jsbundling-rails"
gem "pg"
gem "propshaft"
gem "puma"
gem "redis"
gem "rufus-scheduler"
gem "solid_cache"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"

# ViewComponent
gem "hotwire_combobox", git: "https://github.com/RickHPotter/hotwire_combobox.git", branch: "rick/main"
gem "view_component"
# gem "hotwire_datepicker", git: "https://github.com/RickHPotter/hotwire_datepicker.git"

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

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

group :development, :test do
  gem "bullet"
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails"
end

group :development do
  gem "annotaterb"
  gem "awesome_print"
  gem "better_errors"
  gem "binding_of_caller"
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
end

gem "phlex-rails"

gem "tailwind_merge", "~> 1.1"
