# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :bigint           not null, primary key
#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :bigint           not null
#  user_card_id       :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class CardTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include StartingPriceCallback
  include Installable
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card

  # @validations ..............................................................
  validates :date, :ct_description, :starting_price, :price, :month, :year, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_user_card, ->(user_card_id, user_id) { where(user_card_id:).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }

  # @public_instance_methods ..................................................
  # Defaults description column to a single {#to_s} call.
  #
  # @return [String] The description for an associated transactable.
  #
  def to_s
    ct_description
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
