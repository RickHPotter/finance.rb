# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id             :integer          not null, primary key
#  user_id        :integer          not null
#  card_id        :integer          not null
#  user_card_name :string           not null
#  due_date       :integer          not null
#  min_spend      :decimal(, )      not null
#  credit_limit   :decimal(, )      not null
#  active         :boolean          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class UserCard < ApplicationRecord
  # extends ...................................................................
  # includes ..................................................................
  # security (i.e. attr_accessible) ...........................................
  # relationships .............................................................
  belongs_to :user
  belongs_to :card

  has_many :card_transactions, foreign_key: :card_id

  # validations ...............................................................
  validates :user_card_name, :due_date, :min_spend, :credit_limit, :active, presence: true
  validates :user_card_name, uniqueness: { scope: :user_id }
  validates :due_date, inclusion: { in: 1..31, message: 'must be between 1 and 31' }

  # callbacks .................................................................
  before_validation :set_user_card_name, :set_active, on: :create

  # scopes ....................................................................
  scope :active, -> { where(active: true) }

  # additional config .........................................................
  # class methods .............................................................
  # public instance methods ...................................................
  # protected instance methods ................................................
  # private instance methods ..................................................

  private

  # @return [void]
  #
  # @callback
  #
  def set_user_card_name
    self.user_card_name ||= card.card_name
  end

  # @return [void]
  #
  # @callback
  #
  def set_active
    self.active ||= true
  end
end
