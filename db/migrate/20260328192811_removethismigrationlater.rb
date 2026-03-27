# frozen_string_literal: true

class Removethismigrationlater < ActiveRecord::Migration[8.1]
  def change
    first_stage
    second_stage

    gigi_rec.call
    rikki_rec.call
  end

  def first_stage
    report = Logic::LegacyExchangeReturnRunner.new(dry_run: false).call

    puts "Updated transactions: #{report[:updated_count]}"
    puts "Skipped transactions: #{report[:skipped_count]}"
  end

  def second_stage
    report = Logic::LegacyExchangeReturnConsolidationRunner.new(dry_run: false).call

    puts "Updated families: #{report[:updated_count]}"
    puts "Skipped families: #{report[:skipped_count]}"
  end
end
