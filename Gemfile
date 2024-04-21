# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.2"

# The new Rails 8 asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"

# Use pg as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# ViewComponent
gem "view_component", "~> 3.7"

# Authentication
gem "devise"
gem "letter_opener_web"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Although I like the approach of rails credentials:edit, I thinks it's harder than it should.
gem "dotenv-rails"

gem "dockerfile-rails"

group :development, :test do
  gem "bullet"
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails"
end

group :development do
  gem "annotate"
  gem "awesome_print"
  gem "better_errors"
  gem "binding_of_caller"
  gem "brakeman"
  gem "bundler-audit"
  gem "erb_lint", require: false
  gem "guard-rspec", require: false
  gem "hotwire-livereload"
  gem "rubocop-rails-omakase", require: false
  gem "web-console"

  # NEOVIM IDE / REMEMBER TO UPDATE MASON
  gem "neovim"
  gem "solargraph"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver"
  gem "simplecov", require: false
end
