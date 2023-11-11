# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  date               :date             not null
#  card_id            :integer          not null
#  description        :string           not null
#  comment            :text
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  month              :integer          not null
#  year               :integer          not null
#  installments       :integer          not null
#  installment_number :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class CardTransaction < ApplicationRecord
  # extends ...................................................................
  # includes ..................................................................
  # security (i.e. attr_accessible) ...........................................
  # relationships .............................................................
  belongs_to :card
  belongs_to :category
  belongs_to :category2, class_name: 'Category', foreign_key: 'category2_id'
  belongs_to :entity

  # validations ...............................................................
  validates :date, :card_id, :description, :category_id, :entity_id, :starting_price,
            :price, :month, :year, :installments, :installment_number, presence: true

  # callbacks .................................................................
  # scopes ....................................................................
  scope :by_card, ->(card_id) { where(card_id:) }
  scope :by_category, ->(category_id) { where(category_id:).or(where(category2_id:)) }
  scope :by_entity, ->(entity_id) { where(entity_id:) }
  scope :by_month_year, ->(month, year) { where(month:, year:) }
  scope :by_installments, -> { where('installments > 1') }

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
end
