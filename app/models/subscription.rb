# frozen_string_literal: true

class Subscription < ApplicationRecord
  # @extends ..................................................................
  self.table_name = "finance_subscriptions"

  enum :status, { active: "active", paused: "paused", finished: "finished" }

  # @includes .................................................................
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  has_many :cash_transactions, dependent: :nullify
  has_many :card_transactions, dependent: :nullify

  # @validations ..............................................................
  validates :description, :status, presence: true
  validates :price, numericality: true

  # @callbacks ................................................................
  before_validation :set_defaults, on: :create

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  def transactions
    [ *cash_transactions, *card_transactions ].sort_by(&:date)
  end

  def transactions_count
    cash_transactions.count + card_transactions.count
  end

  def refresh_price!
    update_columns(price: cash_transactions.sum(:price) + card_transactions.sum(:price))
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def set_defaults
    self.status ||= :active
  end
end

# == Schema Information
#
# Table name: finance_subscriptions
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  card_transactions_count :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  comment                 :text
#  description             :string           not null
#  price                   :integer          default(0), not null
#  status                  :string           default("active"), not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_status   (status)
#  index_finance_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
