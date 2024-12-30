# frozen_string_literal: true

# Shared functionality for models that on a particular setting have to create a `cash_transaction`.
module HasAdvancePayments
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    belongs_to :advance_cash_transaction, class_name: "CashTransaction", optional: true, dependent: :destroy

    # @callbacks ..............................................................
    before_create :create_advance_cash_transaction, if: -> { card_advance_category_on_create? }
    before_update :update_advance_cash_transaction
  end

  # @public_class_methods .....................................................

  def card_advance_category_on_create?
    category_transactions.map(&:category).pluck(:category_name).include?("CARD ADVANCE")
  end

  def card_advance_category?
    categories.find_by(category_name: "CARD ADVANCE").present?
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
    in [ true, _, false ]    then destroy_advance_cash_transaction
    else nil
    end
  end

  # Sets `advance_cash_transaction` to nil if the `CARD ADVANCE` category has been removed.
  # It then proceeds to destroy the associated `advance_cash_transaction`.
  #
  # @return [void].
  #
  def destroy_advance_cash_transaction
    cash_transaction_id_to_be_destroyed = advance_cash_transaction_id

    self.advance_cash_transaction = nil
    CashTransaction.find(cash_transaction_id_to_be_destroyed).destroy
  end

  # @see {CashTransaction}.
  #
  # @return [Hash] The params for the associated `advance_cash_transaction`.
  #
  def advance_cash_transaction_params
    {
      description: "CARD ADVANCE [ #{user_card.user_card_name} - #{month_year} ]",
      starting_price: price * -1, price: price * -1,
      date:, month:, year:,
      user_id:,
      cash_transaction_type: model_name.name,
      user_card_id:,
      category_transactions: FactoryBot.build_list(
        :category_transaction, 1, transactable: self, category: user.built_in_category("CARD ADVANCE")
      )
    }
  end
end
