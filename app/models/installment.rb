# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                   :bigint           not null, primary key
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  number               :integer          not null
#  month                :integer          not null
#  year                 :integer          not null
#  installments_count   :integer          default(0), not null
#  card_transaction_id  :bigint           not null
#  money_transaction_id :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Installment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include StartingPriceCallback
  include MoneyTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :card_transaction, counter_cache: true
  delegate :user, :user_id, :user_card, :user_card_id, to: :card_transaction, allow_nil: true

  # @validations ..............................................................
  validates :price, :number, :month, :year, :installments_count, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # Generates a `date` for the associated MoneyTransaction.
  #
  # This method picks the current `due_date` of `user_card` for the MoneyTransaction.
  #
  # @return [Date]
  #
  def money_transaction_date
    date = card_transaction.date
    days = user_card.current_closing_date.day
    next_closing_date = next_date(date:, days:)
    x = if date >= next_closing_date
          number
        else
          number - 1
        end

    next_date(date:, days:, months: x)
  end

  # @protected_instance_methods ...............................................

  protected

  # Generates a `mt_description` for the associated MoneyTransaction.
  #
  # This method generates a description for the MoneyTransaction based on the `user_card` name and month_year.
  #
  # @return [String] The generated description.
  #
  def mt_description
    "Card #{user_card.user_card_name} #{month_year}"
  end

  # Generates a `mt_comment` for the associated MoneyTransaction based on the `user_card` and RefMonthYear.
  #
  # This method generates a comment specifying the user_card and RefMonthYear.
  #
  # @return [String] The generated comment.
  #
  def mt_comment
    installments = Installment.includes(:money_transaction)
                              .where(month:, year:, money_transaction: { user_id:, user_card_id: })
                              .select("money_transaction_id", "installments.price", "installments.installments_count")

    x, y = installments.partition { |installment| installment.installments_count == 1 }
    in_one = x.sum(&:price).round(2)
    spread = y.sum(&:price).round(2)

    "Upfront: #{in_one}, Installments: #{spread}"
  end

  # @private_instance_methods .................................................
end
