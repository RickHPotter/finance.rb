# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  unconfirmed_email      :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  first_name             :string           not null
#  last_name              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class User < ApplicationRecord
  # @extends ..................................................................
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :validatable

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  has_many :user_cards, dependent: :destroy
  has_many :card_transactions, dependent: :destroy
  has_many :user_bank_accounts, dependent: :destroy
  has_many :money_transactions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :entities, dependent: :destroy

  # @validations ..............................................................
  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true
  validates :password, length: { in: 6..22 }

  # @callbacks ................................................................
  before_create :create_built_ins

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # Helper methods to return a full name based on `first_name` and `last_name`.
  #
  # @return [String].
  #
  def full_name
    "#{first_name} #{last_name}"
  end

  # Helper method to return a built-in `category` based on a given `category_name`.
  #
  # @return [Category].
  #
  def built_in_category(category_name)
    categories.find_by(built_in: true, category_name:)
  end

  # Helper method to return the custom `category` instances of given `user`.
  #
  # @return [ActiveRecord::Relation].
  #
  def custom_categories
    categories.where(built_in: false)
  end

  # @protected_instance_methods ...............................................

  protected

  # Creates built-in `categories` for given user.
  #
  # @return [void].
  #
  def create_built_ins
    categories.push(
      Category.new(built_in: true, category_name: "Exchange"),
      Category.new(built_in: true, category_name: "Exchange Return")
    )
  end

  # @private_instance_methods .................................................
end
