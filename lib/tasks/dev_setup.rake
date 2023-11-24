# frozen_string_literal: true

namespace :dev do
  desc 'Setup development environment'
  task setup: :environment do
    p 'Dropping database...'
    `rails db:drop`
    p 'Creating database...'
    `rails db:create`
    p 'Migrating database...'
    `rails db:migrate`
    p 'Seeding database...'
    `rails db:seed`
    p 'Done!'
  end
end
