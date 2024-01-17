# frozen_string_literal: true

# It will prepare the database for the environment
#
def prepare_database
  hash = {
    development: -> { `bin/rails db:drop db:create db:migrate db:seed` },
    test: -> { `bin/rails db:drop db:create db:migrate` },
    production: -> { `bin/rails db:create db:migrate` }
  }

  hash[Rails.env.to_sym].call
end

namespace :env do
  desc 'Setup environment'
  task setup: :environment do
    prepare_database
  end
end
