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
    before_validation :clear_subscription_without_subscription_category
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

  def clear_subscription_without_subscription_category
    return if subscription_id.blank?
    return unless subscription_category_link_removed?
    return if will_save_change_to_subscription_id?

    self.subscription = nil
  end

  def subscription_category_link_removed?
    return false unless respond_to?(:category_transactions)
    return false unless respond_to?(:original_categories)
    return false if original_categories.blank?

    subscription_category_id = user&.built_in_category("SUBSCRIPTION")&.id
    return false if subscription_category_id.blank?

    original_categories.include?(subscription_category_id) && !effective_category_ids.include?(subscription_category_id)
  end

  def effective_category_ids
    category_transactions.reject(&:marked_for_destruction?).filter_map(&:category_id).uniq
  end
end
