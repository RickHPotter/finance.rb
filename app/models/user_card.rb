# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id           :integer          not null, primary key
#  user_id      :integer
#  card_id      :integer
#  card_name    :string           not null
#  due_date     :date             not null
#  min_spend    :decimal(, )      not null
#  credit_limit :decimal(, )      not null
#  active       :boolean          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class UserCard < ApplicationRecord
  # extends ...................................................................
  # includes ..................................................................
  # security (i.e. attr_accessible) ...........................................
  # relationships .............................................................
  belongs_to :user
  belongs_to :card

  has_many :card_transactions

  # validations ...............................................................
  validates :card_name, :due_date, :min_spend, :credit_limit, :active, presence: true
  validates :card_name, uniqueness: true

  # callbacks .................................................................
  before_validation :set_card_name

  # scopes ....................................................................
  scope :active, -> { where(active: true) }

  # additional config .........................................................
  # class methods .............................................................
  # public instance methods ...................................................
  # protected instance methods ................................................
  # private instance methods ..................................................
  private

  def set_card_name
    self.card_name = card.card_name
  end
end
