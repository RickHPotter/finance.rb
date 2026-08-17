# frozen_string_literal: true

class ActionableMessageAutoApplyJob < ApplicationJob
  queue_as :default

  def perform(message)
    Logic::Friendships::AutoAcceptActionableMessageService.new(message).call
  end
end
