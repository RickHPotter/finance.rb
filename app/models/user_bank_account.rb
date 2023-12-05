# frozen_string_literal: true

# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :integer          not null, primary key
#  agency_number  :integer
#  account_number :integer
#  user_id        :integer          not null
#  bank_id        :integer          not null
#  active         :boolean          default(TRUE), not null
#  balance        :decimal(, )      default(0.0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class UserBankAccount < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include ActiveCallback

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :bank

  # @validations ..............................................................
  validates :user_id, :bank_id, :active, :balance, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
