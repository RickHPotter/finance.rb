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
            :price, :month, :year, :installments, :installments_count, presence: true

  # callbacks .................................................................
  before_validation :set_starting_price, on: :create

  # scopes ....................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_card, ->(card_id, user_id) { where(card_id:).by_user(user_id:) }
  scope :by_category, ->(category_id, user_id) { where(category_id:).or(where(category2_id:)).by_user(user_id:) }
  scope :by_entity, ->(entity_id, user_id) { where(entity_id:).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }
  scope :by_installments, ->(user_id) { where('installments_count > 1').by_user(user_id:) }

  # additional config .........................................................
  # class methods .............................................................
  # public instance methods ...................................................
  def month_year
    RefMonthYear.new(month, year).month_year
  end

  # TODO: Create Installments
  #
  # protected instance methods ................................................
  # private instance methods ..................................................
  private

  def set_starting_price
    self.starting_price ||= price
  end
end
