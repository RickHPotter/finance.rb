# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id             :integer          not null, primary key
#  user_card_name :string           not null
#  due_date_day   :integer          not null
#  min_spend      :decimal(, )      not null
#  credit_limit   :decimal(, )      not null
#  active         :boolean          not null
#  user_id        :integer          not null
#  card_id        :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class UserCard < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include ActiveCallback

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :card

  has_many :card_transactions, foreign_key: :card_id

  # @validations ..............................................................
  validates :user_card_name, :due_date_day, :min_spend, :credit_limit, :active,
            :user_id, :card_id, presence: true
  validates :user_card_name, uniqueness: { scope: :user_id }
  # FIXME: Fix the billing cycle by first adding a closing_date
  validates :due_date_day, inclusion: { in: 1..31, message: 'must be between 1 and 31' }

  # @callbacks ................................................................
  before_validation :set_user_card_name, on: :create

  # @scopes ...................................................................
  scope :active, -> { where(active: true) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................

  protected

  # Sets user_card_name in case it was not previously set.
  #
  # @note This is a callback that is called before_validation.
  #
  # @return [void]
  def set_user_card_name
    self.user_card_name ||= card.card_name
  end

  # @private_instance_methods .................................................
end
