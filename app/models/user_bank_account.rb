# frozen_string_literal: true

# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :bigint           not null, primary key
#  agency_number  :integer
#  account_number :integer
#  user_id        :bigint           not null
#  bank_id        :bigint           not null
#  active         :boolean          default(TRUE), not null
#  balance        :decimal(, )      default(0.0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class UserBankAccount < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :bank

  has_many :investments

  # @validations ..............................................................
  validates :active, :balance, presence: true
  validates :bank_id, uniqueness: { scope: %i[agency_number account_number] }

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
