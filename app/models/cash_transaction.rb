# frozen_string_literal: true

class CashTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasCashInstallments
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :imported

  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, counter_cache: true, optional: true

  has_many :card_installments, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :exchanges, dependent: :destroy

  # @validations ..............................................................
  validates :description, :cash_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_paid, on: :create
  after_save :update_associations_count_and_total
  after_destroy :update_associations_count_and_total

  # @scopes ...................................................................
  # @public_instance_methods ..................................................

  def entity_bundle
    return user_card.user_card_name if categories.pluck(:category_name).intersect?([ "CARD ADVANCE", "CARD PAYMENT" ])

    entities.order(:entity_name).pluck(:entity_name).join(", ")
  end

  # Builds `month` and `year` columns for `self` and associated `_installments`.
  #
  # @return [void].
  #
  def build_month_year
    self.date ||= Date.current unless imported
    set_month_year
    cash_installments.each(&:build_month_year)
  end

  def update_associations_count_and_total
    user_bank_account&.update_cash_transactions_total
    categories.each(&:update_cash_transactions_count_and_total)
    entities.each(&:update_cash_transactions_count_and_total)
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return if [ false, true ].include?(paid)

    self.paid = cash_transaction_type == "Investment"
  end
end

# == Schema Information
#
# Table name: cash_transactions
#
#  id                      :bigint           not null, primary key
#  cash_installments_count :integer          default(0), not null
#  cash_transaction_type   :string
#  comment                 :text
#  date                    :date             not null
#  description             :string           not null
#  month                   :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_bank_account_id    :bigint           indexed
#  user_card_id            :bigint           indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_user_bank_account_id  (user_bank_account_id)
#  index_cash_transactions_on_user_card_id          (user_card_id)
#  index_cash_transactions_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
