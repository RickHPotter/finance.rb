# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  starting_price          :integer          not null
#  price                   :integer          not null
#  number                  :integer          not null
#  month                   :integer          not null
#  year                    :integer          not null
#  installment_type        :string           not null
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class CardInstallment < Installment
  # @extends ..................................................................
  delegate :user, :user_id, :user_card, :user_card_id, :date, to: :card_transaction, allow_nil: true

  # @includes .................................................................
  include CashTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :card_transaction, counter_cache: true

  # @validations ..............................................................
  # @callbacks ................................................................
  before_validation :set_installment_type, on: :create

  # @scopes ...................................................................
  default_scope { where(installment_type: :card) }
  scope :by, ->(month:, year:, user_id:, user_card_id:) { joins(:card_transaction).where(month:, year:, card_transaction: { user_id:, user_card_id: }) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # Generates a `date` for the associated `cash_transaction`, picking the `current_due_date` of `user_card` based on the `current_closing_date`.
  #
  # @return [Date].
  #
  def cash_transaction_date
    return end_of_month if card_transaction.imported == true

    closing_days      = user_card.current_closing_date.day
    next_closing_date = next_date(date:, days: closing_days, months: number - 1)
    next_due_date     = next_closing_date + user_card.days_until_due_date

    return next_due_date if next_closing_date > date

    next_date(date: next_due_date, months: 1)
  end

  # @protected_instance_methods ...............................................

  protected

  # Generates a `description` for the associated `cash_transaction` based on the `user_card` name and `month_year`.
  #
  # @return [String] The generated description.
  #
  def description
    "CARD PAYMENT [ #{user_card.user_card_name} - #{month_year} ]"
  end

  # Generates a `comment` for the associated `cash_transaction` based on the `user_card` and `month` and `year`.
  #
  # @return [String] The generated comment.
  #
  def comment
    installments = CardInstallment.by(month:, year:, user_id:, user_card_id:)

    x, y = installments.partition { |installment| installment.card_installments_count == 1 }
    in_one = x.sum(&:price).round(2)
    spread = y.sum(&:price).round(2)

    "Upfront: #{in_one}, Installments: #{spread}"
  end

  # Generates a `category_transactions` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions
    { category_id: user.built_in_category("CARD PAYMENT").id }
  end

  # Generates a `category_transactions_attributes` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions_attributes
    category_transactions.merge(id: nil)
  end

  # @private_instance_methods .................................................

  private

  def set_installment_type
    self.installment_type = :card
  end
end
