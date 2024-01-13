# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                   :bigint           not null, primary key
#  ct_description       :string           not null
#  ct_comment           :text
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  installments_count   :integer          default(0), not null
#  user_id              :bigint           not null
#  user_card_id         :bigint           not null
#  category_id          :bigint           not null
#  category2_id         :bigint
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class CardTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include MoneyTransactable
  include StartingPriceCallback

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card
  belongs_to :category
  belongs_to :category2, class_name: 'Category', foreign_key: 'category2_id', optional: true

  has_many :installments, as: :installable
  has_many :transaction_entities, as: :transactable
  has_many :entities, through: :transaction_entities

  # @validations ..............................................................
  validates :date, :user_card_id, :ct_description, :category_id, :starting_price,
            :price, :month, :year, :installments_count, presence: true

  # @callbacks ................................................................
  # FIXME: this should be an after_save / Fix the docs
  after_create :create_default_installments, unless: installments.present?

  # @scopes ...................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_user_card, ->(user_card_id, user_id) { where(user_card_id:).by_user(user_id:) }
  scope :by_category, ->(category_id, user_id) { where(category_id:).or(where(category2_id:)).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }
  scope :by_installments, ->(user_id) { where('installments_count > 1').by_user(user_id:) }

  # @public_instance_methods ..................................................
  def to_s
    ct_description
  end

  # @protected_instance_methods ...............................................

  protected

  # Create default installments for the CardTransaction when not previously created.
  #
  # This method calculates and creates a specified number of default installments for
  # a CardTransaction, distributing the total price evenly among the installments, and.
  # then calls {#create_installments} to create the actual Installments.
  #
  # @example Create default installments for a CardTransaction
  #   card_transaction = CardTransaction.create(installments_count: 3, price: 100, ...)
  #   => card_transaction.create_default_installments is run
  #   => 3 new installments are created, each with price 33.33, but the last: 33.34
  #
  # @note This is a callback that is called after_create.
  #
  # @note The method uses the `installments_count` attribute to determine the number
  #   of installments to create and distributes the total `price` evenly among them.
  #
  # @return [void]
  #
  def create_default_installments
    calculate_installments(price, installments_count)
    create_installments(prices_arr)
  end

  # TODO: needs doc
  def calculate_installments(price, count)
    prices = (0..count - 2).map { (price / count).round(2) }
    prices << (price - prices.sum)
    prices
  end

  # Create installments based on the provided prices array.
  #
  # @example Create installments for a CardTransaction
  #   card_transaction = CardTransaction.create(installments_count: 3, price: 100, ...)
  #   => prices_arr = [33, 33, 34]
  #   => card_transaction.create_installments(prices_arr)
  #
  # @note The method uses the `installable_id` and `installable_type` attributes
  #   along with the provided `prices_arr` to create installments for the CardTransaction.
  #
  # @param prices_arr [Array<BigDecimal>] An array containing the prices for each installment.
  #
  # @return [void]
  #
  # @see Installment
  #
  def create_installments(prices_arr)
    prices_arr.each_with_index do |price, number|
      installments << Installment.create(number: number + 1, price:)
    end
  end

  # Generates a description for the associated MoneyTransaction.
  #
  # This method generates a description for the MoneyTransaction based on the user's card name and month_year.
  #
  # @return [String] The generated description.
  #
  def mt_description
    "Card #{user_card.user_card_name} #{month_year}"
  end

  # Generates a date for the associated MoneyTransaction.
  #
  # This method picks the due_date for the MoneyTransaction.
  #
  # @return [Date]
  #
  def money_transaction_date
    user_card.current_due_date
  end

  # Generates a comment for the associated MoneyTransaction based on the card and RefMonthYear.
  #
  # This method generates a comment specifying the card and RefMonthYear.
  #
  # @return [String] The generated comment.
  #
  def mt_comment
    a, b = money_transaction.card_transactions.partition { |ct| ct.installments_count == 1 }
    in_one = a.sum(&:price).round(2)
    spread = b.sum(&:price).round(2)

    "Upfront: #{in_one}, Installments: #{spread}"
  end

  # @private_instance_methods .................................................
end
