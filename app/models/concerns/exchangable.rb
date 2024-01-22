# frozen_string_literal: true

# Shared functionality for models that can produce Exchanges.
module Exchangable
  include Backend::MathsHelper
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :exchange_attributes

    # @relationships ..........................................................
    has_many :exchanges, dependent: :destroy

    # @callbacks ..............................................................
    before_validation :check_consistency
    after_validation :update_parent
    before_create :create_exchanges
    before_update :update_exchanges
  end

  # @public_class_methods .....................................................
  def monetary_exchanges
    exchanges.monetary
  end

  # @protected_instance_methods ...............................................

  protected

  def check_consistency
    return unless exchange_attributes&.present? && is_payer

    unless exchange_attributes.is_a?(Array)
      errors.add(:exchanges, 'should be an array')
      return false
    end

    exchange_attributes.each do |exchange|
      unless exchange.is_a?(Hash)
        errors.add(:exchanges, 'should be an array of hashes')
        return false
      end

      unless Exchange.new(exchange.merge(entity_transaction: self)).valid?
        errors.add(:exchanges, 'should be an array of hashes of valid exchanges')
        return false
      end
    end
  end

  def update_parent
    return if exchange_attributes.blank?
    return unless exchange_attributes.pluck(:exchange_type).uniq == [:non_monetary]

    self.status = :finished
  end

  # Create exchanges based on the provided `exchange_attributes` array of hashes.
  #
  # @example Create exchanges through a CardTransaction
  #   card_transaction = CardTransaction.create(
  #     date: Date.current, user_id: User.first.id,
  #     user_card_id: User.first.user_cards.ids.sample,
  #     ct_description: 'testing', price: 4.00,
  #     month: Date.current.month, year: Date.current.year,
  #     entity_transaction_attributes: [
  #       {
  #         entity_id: User.first.entities.ids.sample,
  #         is_payer: true, price: 4.00,
  #         exchange_attributes: [
  #           { exchange_type: :monetary, price: 2.00 },
  #           { exchange_type: :monetary, price: 2.00 }
  #         ]
  #       }
  #     ]
  #   )
  #   => create_exchanges is run before_create
  #   => two exchanges are created for given entity
  #
  # @note The method uses the provided `exchange_attributes` to create exchanges
  #   for the entity transaction.
  # @note This is a method that is called before_create.
  #
  # @return [void]
  #
  # @see Exchange
  #
  def create_exchanges
    return unless exchange_attributes&.present?

    exchange_attributes.each_with_index do |attributes, index|
      exc = Exchange.new(attributes.merge(number: index + 1))
      exchanges.push(exc) unless exchanges.include?(exc)
    end

    destroy_exchange_attributes
  end

  # Update exchanges based on a set of conditions.
  #
  # In case there were no exchanges to begin with, they are created instead of updated.
  # In case there were exchanges, they are deleted and then updated.
  # In case there were exchanges, `is_payer` == false, then the creation of exchanges is avoided.
  #
  # @note This is a method that is called before_update.
  #
  # @return [void]
  #
  # FIXME: REFACTOR
  def update_exchanges
    destroy_exchanges if !is_payer && changes[:is_payer]

    if exchange_attributes.present? && is_payer
      exchanges.destroy_all
      create_exchanges
    end

    # TODO: in favour of counter_cache
    self.exchanges_count = exchanges.count
  end

  def destroy_exchanges
    exchanges.destroy_all

    # FIXME: this can be done in a better way, I suppose
    # plus it should only happen IF none of the transactionEntities are payers
    # category_id = transactable.user.categories.find_by(category_name: 'Exchange').id
    # category_transaction_attributes = (transactable.category_transaction_attributes || []) - [{ category_id: }]
    # transactable.category_transaction_attributes = category_transaction_attributes
  end

  def destroy_exchange_attributes
    self.exchange_attributes = nil
  end
end
