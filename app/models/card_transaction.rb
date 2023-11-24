# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  date               :date             not null
#  description        :string           not null
#  comment            :text
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  month              :integer          not null
#  year               :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  installment_id     :integer          not null
#  installments_count :integer          default(0), not null
#  card_id            :integer
#  user_id            :integer
#
class CardTransaction < ApplicationRecord
  # extends ...................................................................
  # includes ..................................................................
  # security (i.e. attr_accessible) ...........................................
  # relationships .............................................................
  belongs_to :user_card
  belongs_to :category
  belongs_to :category2, class_name: 'Category', foreign_key: 'category2_id'
  belongs_to :entity

  has_many :installments, as: :installable

  # validations ...............................................................
  validates :date, :card_id, :description, :category_id, :entity_id, :starting_price,
            :price, :month, :year, :installments_count, presence: true

  # callbacks .................................................................
  before_validation :set_starting_price, :set_active, on: :create

  # scopes ....................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_card, ->(card_id, user_id) { where(card_id:).by_user(user_id:) }
  scope :by_category, ->(category_id, user_id) { where(category_id:).or(where(category2_id:)).by_user(user_id:) }
  scope :by_entity, ->(entity_id, user_id) { where(entity_id:).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }
  scope :by_installments, ->(user_id) { where('installments_count > 1').by_user(user_id:) }

  def month_year
    RefMonthYear.new(month, year).month_year
  end

  # Create default installments for the CardTransaction.
  #
  # This method creates a specified number of default installments for a CardTransaction,
  # distributing the total price evenly among the installments.
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
    installable_id = id
    installable_type = 'CardTransaction'
    remaining = price

    (1...installments_count).each do |number|
      price = self.price / installments_count.to_d
      Installment.create!(installable_id:, installable_type:, number:, price:)
      remaining -= price
    end

    Installment.create!(installable_id:, installable_type:, number: installments_count, price: remaining)
  end

  # protected instance methods ................................................
  # private instance methods ..................................................
  private

  # @return [void]
  #
  # @callback
  #
  def set_starting_price
    self.starting_price ||= price
  end

  # @return [void]
  #
  # @callback
  #
  def set_active
    self.active = true
  end
end
