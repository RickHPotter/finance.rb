# frozen_string_literal: true

class UserBankAccount < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :bank

  has_many :cash_transactions, dependent: :destroy
  has_many :investments, dependent: :destroy

  # @validations ..............................................................
  validates :balance, presence: true
  validates :bank_id, uniqueness: { scope: %i[agency_number account_number] }

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :bigint           not null, primary key
#  account_number :integer
#  active         :boolean          default(TRUE), not null
#  agency_number  :integer
#  balance        :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  bank_id        :bigint           not null, indexed
#  user_id        :bigint           not null, indexed
#
# Indexes
#
#  index_user_bank_accounts_on_bank_id  (bank_id)
#  index_user_bank_accounts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id)
#  fk_rails_...  (user_id => users.id)
#
