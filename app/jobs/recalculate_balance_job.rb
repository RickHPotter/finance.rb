# frozen_string_literal: true

class RecalculateBalanceJob < ApplicationJob
  queue_as :default

  def perform(user:)
    Logic::RecalculateBalancesService.new(user:).call
  end
end
