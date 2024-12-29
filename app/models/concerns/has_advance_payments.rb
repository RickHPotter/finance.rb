# frozen_string_literal: true

# Shared functionality for models that on a particular setting have to create a `money_transaction`.
module HasAdvancePayments
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    belongs_to :advance_money_transaction, class_name: "MoneyTransaction", optional: true, dependent: :destroy

    # @callbacks ..............................................................
    before_create :create_advance_money_transaction, if: -> { card_advance_category_on_create? }
    before_update :update_advance_money_transaction
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

  # Creates a new `advance_money_transaction` if it has a `CARD ADVANCE` category.
  #
  # @note This is a method that is called before_create.
  #
  # @see {MoneyTransaction}.
  # @see {#advance_money_transaction_params}.
  #
  # @return [void].
  #
  def create_advance_money_transaction
    self.advance_money_transaction = MoneyTransaction.create(advance_money_transaction_params)
  end

  # @note This is a method that is called before_update.
  #
  # @see {#create_advance_money_transaction}.
  # @see {#advance_money_transaction_params}.
  #
  # @return [void].
  #
  def update_advance_money_transaction
    has_changes = (changes.keys - %w[created_at updated_at]).present?

    case [ advance_money_transaction.present?, has_changes, card_advance_category? ]
    in [ true, true, true ]  then advance_money_transaction.update(advance_money_transaction_params)
    in [ false, _, true ]    then create_advance_money_transaction
    in [ true, _, false ]    then destroy_advance_money_transaction
    else nil
    end
  end

  # Sets `advance_money_transaction` to nil if the `CARD ADVANCE` category has been removed.
  # It then proceeds to destroy the associated `advance_money_transaction`.
  #
  # @return [void].
  #
  def destroy_advance_money_transaction
    money_transaction_id_to_be_destroyed = advance_money_transaction_id

    self.advance_money_transaction = nil
    MoneyTransaction.find(money_transaction_id_to_be_destroyed).destroy
  end

  # @see {MoneyTransaction}.
  #
  # @return [Hash] The params for the associated `advance_money_transaction`.
  #
  def advance_money_transaction_params
    {
      mt_description: "#{ct_description} - CARD ADVANCE [ #{user_card.user_card_name} ]",
      starting_price: price * -1, price: price * -1,
      date:, month:, year:,
      user_id:,
      money_transaction_type: model_name.name,
      user_card_id:,
      category_transactions: FactoryBot.build_list(
        :category_transaction, 1, transactable: self, category: user.built_in_category("CARD ADVANCE")
      )
    }
  end
end
