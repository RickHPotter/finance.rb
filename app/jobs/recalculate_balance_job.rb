# frozen_string_literal: true

class RecalculateBalanceJob < ApplicationJob
  queue_as :default

  def perform(user:, context: nil)
    contexts = context ? Array(context) : user.contexts.to_a

    contexts.each do |resolved_context|
      Logic::RecalculateBalancesService.new(user:, context: resolved_context).call
    end
  end
end
