# frozen_string_literal: true

# Shared functionality for transaction models that can belong to a `subscription`.
module HasSubscription
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :original_subscription_id

    # @relationships ..........................................................
    belongs_to :subscription, optional: true, counter_cache: true

    # @callbacks ..............................................................
    before_destroy :remember_subscription_id, prepend: true
    after_commit :update_subscription_price_cache
  end

  # @public_instance_methods ..................................................

  def update_subscription_price_cache
    subscription_ids = [ subscription_id, original_subscription_id, previous_changes.dig("subscription_id", 0) ].compact.uniq
    Subscription.where(id: subscription_ids).find_each(&:refresh_price!)
  end

  # @protected_instance_methods ...............................................

  protected

  def remember_subscription_id
    self.original_subscription_id = subscription_id
  end
end
