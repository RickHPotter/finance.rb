# frozen_string_literal: true

# == Schema Information
#
# Table name: cash_transactions
#
#  id                      :bigint           not null, primary key
#  description             :string           not null
#  comment                 :text
#  date                    :date             not null
#  month                   :integer          not null
#  year                    :integer          not null
#  starting_price          :integer          not null
#  price                   :integer          not null
#  paid                    :boolean          default(FALSE)
#  cash_transaction_type   :string
#  cash_installments_count :integer          default(0), not null
#  user_id                 :bigint           not null
#  user_card_id            :bigint
#  user_bank_account_id    :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class CashTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice
  include HasCashInstallments
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, optional: true
  belongs_to :user_bank_account, optional: true

  has_many :card_installments, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :exchanges, dependent: :destroy

  # @validations ..............................................................
  validates :description, :date, :month, :year, :starting_price, :price, presence: true
  validates :paid, inclusion: { in: [ true, false ] }

  # @callbacks ................................................................
  before_validation :set_paid, on: :create

  # @scopes ...................................................................
  scope :by_user, ->(user) { where(user:) }
  scope :check_helper, lambda { |year, month|
    where("extract(year from date) = ? AND extract(month from date) = ? AND (PRICE > 0 OR PRICE < 0)", year, month)
      .order(:date)
  }
  scope :check_helper_by_date, lambda { |year, month|
    where("extract(year from date) = ? AND extract(month from date) = ? AND (PRICE > 0 OR PRICE < 0)", year, month)
      .order(:date)
      .group_by(&:date)
  }
  scope :check_helper_by_date_pluck, lambda { |year, month|
    where("extract(year from date) = ? AND extract(month from date) = ? AND (PRICE > 0 OR PRICE < 0)", year, month)
      .order(:date)
      .group_by(&:date)
      .transform_values { |v| v.map! { |e| [ e.description, e.price ] } }
  }

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
    set_month_year
    cash_installments.each(&:build_month_year)
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
    return if paid.present?

    self.paid = true if cash_transaction_type == "INVESTMENT"
    self.paid = date.present? && Date.current >= date
  end
end
