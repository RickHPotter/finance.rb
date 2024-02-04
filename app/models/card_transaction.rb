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
#  installments_count   :integer          default(1), not null
#  user_id              :bigint           not null
#  user_card_id         :bigint           not null
#  money_transaction_id :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class CardTransaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include StartingPriceCallback
  include MoneyTransactable
  # include CategoryTransactable
  # include EntityTransactable
  # include Installable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :user_card

  has_many :installments, as: :installable, dependent: :destroy
  accepts_nested_attributes_for :installments, allow_destroy: true, reject_if: :all_blank

  # @validations ..............................................................
  validates :date, :ct_description, :starting_price, :price, :month, :year, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  scope :by_user, ->(user_id) { where(user_id:) }
  scope :by_user_card, ->(user_card_id, user_id) { where(user_card_id:).by_user(user_id:) }
  scope :by_month_year, ->(month, year, user_id) { where(month:, year:).by_user(user_id:) }
  scope :by_installable, ->(user_id) { where(installments_count: 2..).by_user(user_id:) }

  # @public_instance_methods ..................................................
  # Defaults description column to a single {#to_s} call.
  #
  # @return [String] The description for an associated transactable.
  #
  def to_s
    ct_description
  end

  # @protected_instance_methods ...............................................

  protected

  # Generates a description for the associated MoneyTransaction.
  #
  # This method generates a description for the MoneyTransaction based on the user's card name and month_year.
  #
  # @return [String] The generated description.
  #
  def mt_description
    "Card #{user_card.user_card_name} #{month_year}"
  end

  # Generates a comment for the associated MoneyTransaction based on the card and RefMonthYear.
  #
  # This method generates a comment specifying the card and RefMonthYear.
  #
  # @return [String] The generated comment.
  #
  def mt_comment
    siblings = money_transaction&.card_transactions
    siblings ||= [self]

    # FIXME: this logic seems accurate, but it's not getting the installment
    # price, but the whole thing when it is installable, plus, as of now
    # it does not get other months installables that are present here
    a, b = siblings.partition { |ct| ct.installments_count == 1 }
    in_one = a.sum(&:price).round(2)
    spread = b.sum(&:price).round(2)

    "Upfront: #{in_one}, Installments: #{spread}"
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

  # @private_instance_methods .................................................
end
