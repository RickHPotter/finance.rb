# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Subscriptions::LifecycleTransition do
  let(:user) { create(:user, :random) }

  describe ".call" do
    {
      pause: { active: :paused },
      resume: { paused: :active },
      finish: { active: :finished, paused: :finished },
      reopen: { finished: :active }
    }.each do |event, transitions|
      transitions.each do |from, to|
        it "transitions #{from} to #{to} on #{event}" do
          subscription = create(:subscription, user:, context: user.main_context, status: from)

          result = described_class.call(subscription:, event:)

          expect(result).to eq(subscription)
          expect(subscription.reload.status).to eq(to.to_s)
        end
      end
    end

    it "rejects events that are invalid for the locked current state" do
      subscription = create(:subscription, user:, context: user.main_context, status: :finished)

      expect do
        described_class.call(subscription:, event: :pause)
      end.to raise_error(described_class::InvalidTransition)

      expect(subscription.reload).to be_finished
    end

    it "rejects unknown events without changing the Subscription" do
      subscription = create(:subscription, user:, context: user.main_context, status: :active)

      expect do
        described_class.call(subscription:, event: :archive)
      end.to raise_error(described_class::InvalidTransition, /Unknown Subscription lifecycle event/)

      expect(subscription.reload).to be_active
    end

    it "reloads stale instances after acquiring the lock before resolving a transition" do
      subscription = create(:subscription, user:, context: user.main_context, status: :active)
      first_request = Subscription.find(subscription.id)
      stale_second_request = Subscription.find(subscription.id)

      described_class.call(subscription: first_request, event: :finish)

      expect do
        described_class.call(subscription: stale_second_request, event: :pause)
      end.to raise_error(described_class::InvalidTransition)

      expect(stale_second_request.reload).to be_finished
    end
  end
end
