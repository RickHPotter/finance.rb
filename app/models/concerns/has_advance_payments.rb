# frozen_string_literal: true

# Shared functionality for models that on a particular setting have to create a `cash_transaction`.
module HasAdvancePayments
  extend ActiveSupport::Concern

  include TranslateHelper

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :destroy_advance_cash_transaction_id

    # @relationships ..........................................................
    belongs_to :advance_cash_transaction, class_name: "CashTransaction", optional: true, dependent: :destroy

    # @callbacks ..............................................................
    before_create :create_advance_cash_transaction, if: -> { card_advance_category? }
    before_update :update_advance_cash_transaction
    before_destroy :prepare_advance_cash_transaction_destruction
    after_commit :destroy_advance_cash_transaction, on: %i[update destroy]
  end

  # @public_class_methods .....................................................

  def card_advance_category?
    categories.map(&:category_name).include? "CARD ADVANCE"
  end

  # @protected_instance_methods ...............................................

  protected

  # Creates a new `advance_cash_transaction` if it has a `CARD ADVANCE` category.
  #
  # @note This is a method that is called before_create.
  #
  # @see {CashTransaction}.
  # @see {#advance_cash_transaction_params}.
  #
  # @return [void].
  #
  def create_advance_cash_transaction
    self.advance_cash_transaction = CashTransaction.create(advance_cash_transaction_params)
  end

  # @note This is a method that is called before_update.
  #
  # @see {#create_advance_cash_transaction}.
  # @see {#advance_cash_transaction_params}.
  #
  # @return [void].
  #
  def update_advance_cash_transaction
    has_changes = (changes.keys - %w[created_at updated_at]).present?

    case [ advance_cash_transaction.present?, has_changes, card_advance_category? ]
    in [ true, true, true ]  then advance_cash_transaction.update(advance_cash_transaction_params)
    in [ false, _, true ]    then create_advance_cash_transaction
    in [ true, _, false ]    then prepare_advance_cash_transaction_destruction
    else nil
    end
  end

  def prepare_advance_cash_transaction_destruction
    self.destroy_advance_cash_transaction_id = advance_cash_transaction_id
    self.advance_cash_transaction_id = nil
  end

  def destroy_advance_cash_transaction
    return unless destroy_advance_cash_transaction_id

    CashTransaction.find_by(id: destroy_advance_cash_transaction_id)&.destroy
    self.destroy_advance_cash_transaction_id = nil
  end

  def cash_installments_attributes
    [ { number: 1, price: price * - 1, installment_type: :CashTransaction, date:, month: date.month, year: date.year, paid: true } ]
  end

  def category_transactions_attributes
    [ { category_id: user.built_in_category("CARD ADVANCE").id } ]
  end

  def entity_transactions_attributes
    [ { id: nil, is_payer: false, price: 0, entity_id: user.entities.find_or_create_by(entity_name: user_card.user_card_name).id } ]
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `advance_cash_transaction`.
  #
  def advance_cash_transaction_params
    {
      description: "#{model_attribute(Category, :card_advance).upcase}  [ #{user_card.user_card_name} - #{month_year} ]",
      starting_price: price * -1, price: price * -1,
      date:, month: date.month, year: date.year,
      user_id:,
      cash_transaction_type: model_name.name,
      user_card_id:,
      cash_installments_attributes:,
      entity_transactions_attributes:,
      category_transactions_attributes:
    }
  end
end
