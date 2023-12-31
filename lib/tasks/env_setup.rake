# frozen_string_literal: true

def prepare_database
  hash = {
    development: `rails db:prepare`,
    test: `rails db:drop db:create db:migrate`,
    production: `rails db:create db:migrate`
  }

  hash[Rails.env.to_sym]
end

namespace :env do
  desc 'Setup development environment'
  task setup: :environment do
    prepare_database
  end
end
