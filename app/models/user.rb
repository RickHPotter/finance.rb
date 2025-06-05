# frozen_string_literal: true

class User < ApplicationRecord
  # @extends ..................................................................
  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable, :validatable

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  has_many :card_transactions, dependent: :destroy
  has_many :card_installments, through: :card_transactions
  has_many :advance_cash_transactions, through: :card_transactions

  has_many :cash_transactions, dependent: :destroy
  has_many :cash_installments, through: :cash_transactions

  has_many :investments, dependent: :destroy

  has_many :user_cards, dependent: :destroy
  has_many :user_bank_accounts, dependent: :destroy

  has_many :budgets, dependent: :destroy

  has_many :categories, dependent: :destroy
  has_many :entities, dependent: :destroy

  # @validations ..............................................................
  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true
  validates :password, length: { in: 6..22 }

  # @callbacks ................................................................
  before_validation :set_default_locale
  before_create :create_built_ins
  before_create :set_confirmed_at

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

  def set_default_locale
    self.locale ||= I18n.locale
  end

  # Creates built-in `categories` for given user.
  #
  # @return [void].
  #
  def create_built_ins
    categories.push(
      Category.new(built_in: true, category_name: "CARD PAYMENT"),
      Category.new(built_in: true, category_name: "CARD ADVANCE"),
      Category.new(built_in: true, category_name: "CARD INSTALLMENT"),
      Category.new(built_in: true, category_name: "INVESTMENT"),
      Category.new(built_in: true, category_name: "EXCHANGE"),
      Category.new(built_in: true, category_name: "EXCHANGE RETURN"),
      Category.new(built_in: false, category_name: "BORROW RETURN")
    )
  end

  # TODO: setting up a free SMTP server comes first
  # and maybe even before that, switching from Devise to Auth-Zero
  def set_confirmed_at
    self.confirmed_at = Time.zone.today
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string           indexed
#  confirmed_at           :datetime
#  email                  :string           default(""), not null, indexed
#  encrypted_password     :string           default(""), not null
#  first_name             :string           not null
#  last_name              :string           not null
#  locale                 :string           not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string           indexed
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
