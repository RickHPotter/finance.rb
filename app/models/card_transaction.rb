# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  date               :date             not null
#  ct_description     :string           not null
#  ct_comment         :text
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  month              :integer          not null
#  year               :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  installments_count :integer          default(0), not null
#  card_id            :integer          not null
#  user_id            :integer          not null
#
class CardTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card, class_name: 'UserCard', foreign_key: :card_id
  belongs_to :category
  belongs_to :category2, class_name: 'Category', foreign_key: 'category2_id', optional: true
  belongs_to :entity

  has_many :installments, as: :installable

  # @validations ..............................................................
  validates :date, :card_id, :ct_description, :category_id, :entity_id, :starting_price,
            :price, :month, :year, :installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_starting_price, on: :create
  after_create :create_default_installments

  # @scopes ...................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_card, ->(card_id, user_id) { where(card_id:).by_user(user_id:) }
  scope :by_category, ->(category_id, user_id) { where(category_id:).or(where(category2_id:)).by_user(user_id:) }
  scope :by_entity, ->(entity_id, user_id) { where(entity_id:).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }
  scope :by_installments, ->(user_id) { where('installments_count > 1').by_user(user_id:) }

  # Get the formatted month and year string.
  #
  # @return [String] Formatted month and year string in the format "MONTH <YEAR>"
  #
  # @note This method internally uses the RefMonthYear#month_year.
  #
  def month_year
    RefMonthYear.new(month, year).month_year
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets starting_price based on the price on create.
  #
  # @note This is a callback that is called before_create.
  #
  # @return [void]
  def set_starting_price
    self.starting_price ||= price
  end

  # Create default installments for the CardTransaction when not previously created.
  #
  # This method calculates and creates a specified number of default installments for
  # a CardTransaction, distributing the total price evenly among the installments.
  #
  # @return [void]
  #
  # @example Create default installments for a CardTransaction
  #   card_transaction = CardTransaction.new(installments_count: 3, price: 100)
  #   card_transaction.create_default_installments
  #
  # @note The method uses the `installments_count` attribute to determine the number
  #   of installments to create and distributes the total `price` evenly among them.
  #
  def create_default_installments
    return if installments.present?

    prices_arr = (0..installments_count - 2).map { (price / installments_count).round(2) }
    prices_arr << (price - prices_arr.sum)

    create_installments(prices_arr)
  end

  # Create installments based on the provided prices array.
  #
  # @example Create installments for a CardTransaction
  #   card_transaction = CardTransaction.new(installments_count: 3, price: 100)
  #   prices_arr = [33, 33, 34]
  #   card_transaction.create_installments(prices_arr)
  #
  # @note The method uses the `installable_id` and `installable_type` attributes
  #   along with the provided `prices_arr` to create installments for the CardTransaction.
  #
  # @param prices_arr [Array<BigDecimal>] An array containing the prices for each installment.
  #
  # @return [void]
  #
  def create_installments(prices_arr)
    prices_arr.each_with_index do |price, number|
      installments << Installment.create(number: number + 1, price:)
    end
  end

  # @private_instance_methods .................................................
end
