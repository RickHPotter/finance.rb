# frozen_string_literal: true

class User < ApplicationRecord
  # @extends ..................................................................
  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable, :validatable

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  attr_writer :first_name, :last_name, :locale

  # @relationships ............................................................
  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_one :preference, class_name: "UserPreference", dependent: :destroy

  has_many :card_transactions, dependent: :destroy
  has_many :card_installments, through: :card_transactions
  has_many :advance_cash_transactions, through: :card_transactions

  has_many :cash_transactions, dependent: :destroy
  has_many :cash_installments, through: :cash_transactions

  has_many :investments, dependent: :destroy

  has_many :user_cards, dependent: :destroy
  has_many :user_bank_accounts, dependent: :destroy

  has_many :budgets, dependent: :destroy
  has_many :contexts, dependent: :destroy
  has_many :health_check_runs, dependent: :destroy
  has_many :connected_health_check_runs,
           class_name: "HealthCheckRun",
           foreign_key: :connected_user_id,
           inverse_of: :connected_user,
           dependent: :destroy

  has_many :categories, dependent: :destroy
  has_many :entities, dependent: :destroy

  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants

  has_many :sent_messages, ->(user) { where(user_id: user.id) }, through: :conversations, source: :messages
  has_many :received_messages, ->(user) { where.not(user_id: user.id) }, through: :conversations, source: :messages

  has_many :subscriptions, class_name: "Subscription", dependent: :destroy
  has_many :push_subscriptions, class_name: "PushSubscription", dependent: :destroy

  # @validations ..............................................................
  validates :email, presence: true
  validates :first_name, :last_name, presence: true, on: :create
  validates :email, uniqueness: true
  validates :password, length: { in: 6..22 }

  # @callbacks ................................................................
  before_create -> { self.public_id ||= SecureRandom.uuid }
  before_create :create_built_ins
  before_create :set_confirmed_at
  after_create :create_main_context
  after_create :create_default_profile_and_preference!

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  delegate :display_name, to: :profile, allow_nil: true

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
    category = categories.find_or_create_by(category_name:) { |record| record.built_in = true }
    category.update!(built_in: true) unless category.built_in?

    category
  end

  def built_in_entity(entity_name = nil)
    scope = entities.where(built_in: true)
    return scope.first if entity_name.nil?

    scope.find_by(entity_name:)
  end

  # Helper method to return the custom `category` instances of given `user`.
  #
  # @return [ActiveRecord::Relation].
  #
  def custom_categories
    categories.where("built_in = false OR category_name IN ('INVESTMENT', 'BORROW RETURN', 'PIGGY BANK')")
  end

  def main_context
    contexts.main.first
  end

  def ensure_main_context!
    return main_context if main_context.present?

    contexts.create!(name: "Main", main: true)
  end

  def friendship_with(other_user)
    Friendship.where(user_id: [ id, other_user.id ], friend_id: [ id, other_user.id ]).first
  end

  # @protected_instance_methods ...............................................

  def first_name
    if has_attribute?(:first_name)
      profile&.first_name || read_attribute(:first_name) || @first_name
    else
      profile&.first_name || @first_name
    end
  end

  def last_name
    if has_attribute?(:last_name)
      profile&.last_name || read_attribute(:last_name) || @last_name
    else
      profile&.last_name || @last_name
    end
  end

  def locale
    if has_attribute?(:locale)
      profile&.locale || read_attribute(:locale) || @locale || "en"
    else
      profile&.locale || @locale || "en"
    end
  end

  def timezone
    profile&.timezone || "UTC"
  end

  def theme
    preference&.theme || "system"
  end

  def default_cash_transaction_user_bank_account
    preference&.default_cash_transaction_user_bank_account_id || user_bank_accounts.active.first&.id
  end

  protected

  def create_default_profile_and_preference!
    create_profile!(
      first_name:,
      last_name:,
      locale: locale || "en",
      timezone: "UTC"
    )

    create_preference!(
      theme: "system",
      landing_page: "cash_transactions",
      exchange_default_bound_type: "standalone",
      row_color_mode: "badges_only",
      default_card_transaction_date_order: "card_installment_date",
      default_cash_transaction_date_order: "cash_transaction_date"
    )
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
      Category.new(built_in: true, category_name: "SUBSCRIPTION"),
      Category.new(built_in: true, category_name: "EXCHANGE"),
      Category.new(built_in: true, category_name: "EXCHANGE RETURN"),
      Category.new(built_in: true, category_name: "PIGGY BANK"),
      Category.new(built_in: true, category_name: "PIGGY BANK RETURN"),
      Category.new(built_in: true, category_name: "BORROW RETURN"),
      Category.new(built_in: true, category_name: "FAILED LEND/BORROW RETURN")
    )

    entities.push(Entity.new(built_in: true, entity_name: "MOI"))
  end

  # TODO: make more visible to the user that they need to confirm their email
  # and maybe even before that, switching from Devise to Auth-Zero
  def set_confirmed_at
    self.confirmed_at = Time.zone.today
  end

  def create_main_context
    ensure_main_context!
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  admin                  :boolean          default(FALSE), not null
#  confirmation_sent_at   :datetime
#  confirmation_token     :string           uniquely indexed
#  confirmed_at           :datetime
#  email                  :string           default(""), not null, uniquely indexed
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string           uniquely indexed
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  public_id              :string           not null, uniquely indexed
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_public_id             (public_id) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
