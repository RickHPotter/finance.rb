# frozen_string_literal: true

class Category < ApplicationRecord
  # @extends ..................................................................
  BG_COLOURS = {
    "FOOD" => "bg-meat",
    "GROCERY" => "bg-lettuce",
    "EDUCATION" => "bg-book",
    "RENT" => "bg-urgency",
    "NEEDS" => "bg-urgency",
    "GIFT" => "bg-gift",
    "TRANSPORT" => "bg-honda",
    "SALARY" => "bg-money",
    "CARD PAYMENT" => "bg-money",
    "CARD ADVANCE" => "bg-money",
    "CARD DISCOUNT" => "bg-money",
    "CARD REVERSAL" => "bg-money",
    "DEPOSIT" => "bg-money",
    "PROMO" => "bg-money",
    "INVESTMENT" => "bg-gold",
    "SELL" => "bg-oldmoney",
    "LEISURE" => "bg-fun",
    "BILL" => "bg-gray-400",
    "FEES" => "bg-gray-400",
    "BET" => "bg-gray-600",
    "GODSEND" => "bg-greek",
    "EXCHANGE" => "bg-yellow-400",
    "EXCHANGE RETURN" => "bg-yellow-600"
  }.freeze

  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  has_many :category_transactions, dependent: :destroy
  has_many :card_transactions, through: :category_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :cash_transactions, through: :category_transactions, source: :transactable, source_type: "CashTransaction"
  has_many :investments, through: :category_transactions, source: :transactable, source_type: "Investment"

  # @validations ..............................................................
  validates :category_name, presence: true, uniqueness: { scope: :user_id }
  validates :built_in, inclusion: { in: [ true, false ] }

  # @callbacks ................................................................
  before_validation :set_built_in

  # @scopes ...................................................................
  scope :built_in, -> { where(built_in: true) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # @return [Boolean].
  #
  def built_in?
    built_in
  end

  # TODO: later there will be a colour-picker and a colour column for this table
  def bg_colour
    BG_COLOURS[category_name]
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets `built_in` in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_built_in
    self.built_in ||= false
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: categories
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE), not null
#  built_in      :boolean          default(FALSE), not null
#  category_name :string           not null, indexed => [user_id]
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null, indexed, indexed => [category_name]
#
# Indexes
#
#  index_categories_on_user_id           (user_id)
#  index_category_name_on_composite_key  (user_id,category_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
