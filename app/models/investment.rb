# frozen_string_literal: true

class Investment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include CashTransactable
  include CategoryTransactable
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_bank_account

  # @validations ..............................................................
  validates :price, :date, :description, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Generates a `description` for the associated `cash_transaction` based on the `user`'s `bank_name` and `month_year`.
  #
  # @return [String] The generated description.
  #
  def cash_transaction_description
    "#{pluralise_model(Investment, 1).upcase} #{user_bank_account.user_bank_account_name} #{month_year}"
  end

  # Generates a `date` for the associated `cash_transaction`, picking the end of given `month` for the `cash_transaction`.
  #
  # @return [Date].
  #
  def card_payment_date
    beginning_of_month
  end

  # Generates a comment for the associated `cash_transaction` based on investment days.
  #
  # @return [String] The generated comment.
  #
  def comment
    "Days: [#{cash_transaction.investments.order(:date).map(&:day).join(', ')}]"
  end

  # Generates a `category_transactions` for the associated `cash_transaction` that mounts up the investment entries.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions
    { category_id: user.built_in_category("INVESTMENT").id }
  end

  # Generates a `category_transactions_attributes` for the associated `cash_transaction` that mounts up the investment entries.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions_attributes
    category_transactions.merge(id: nil)
  end

  # Generates a `entity_transactions_attributes` for the associated `cash_transaction` that mounts up the investment entries.
  #
  # @return [Hash] The generated attributes.
  #
  def entity_transactions_attributes
    [ { id: nil, is_payer: false, price: 0, entity_id: user.entities.find_or_create_by(entity_name: user_bank_account.user_bank_account_name).id } ]
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  date                 :datetime         not null
#  description          :string
#  month                :integer          not null
#  price                :integer          not null
#  year                 :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cash_transaction_id  :bigint           indexed
#  user_bank_account_id :bigint           not null, indexed
#  user_id              :bigint           not null, indexed
#
# Indexes
#
#  index_investments_on_cash_transaction_id   (cash_transaction_id)
#  index_investments_on_user_bank_account_id  (user_bank_account_id)
#  index_investments_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_id => users.id)
#
