# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  first_name             :string           not null
#  last_name              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class User < ApplicationRecord
  # @extends ..................................................................
  # @TODO: Add :confirmable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  has_many :user_cards
  has_many :card_transactions
  has_many :user_bank_accounts
  has_many :money_transactions
  has_many :categories
  has_many :entities

  # @validations ..............................................................
  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true
  validates :password, length: { in: 6..22 }

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # Helper methods to return a full name based on first_name and last_name
  #
  # @return [String]
  #
  def full_name
    "#{first_name} #{last_name}"
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
