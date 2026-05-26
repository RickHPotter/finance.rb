# frozen_string_literal: true

class Entity < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :entity_user, class_name: "User", optional: true

  has_many :entity_transactions, dependent: :destroy
  has_many :card_transactions, through: :entity_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :cash_transactions, through: :entity_transactions, source: :transactable, source_type: "CashTransaction"

  # @validations ..............................................................
  validates :entity_name, presence: true, uniqueness: { scope: :user_id }
  validates :built_in, inclusion: { in: [ true, false ] }
  validate :prevent_deactivation_when_built_in

  # @callbacks ................................................................
  before_validation :set_built_in
  before_destroy :prevent_destroy_when_built_in

  # @scopes ...................................................................
  scope :built_in, -> { where(built_in: true) }
  scope :that_are_users, -> { where.not(entity_user_id: nil) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def built_in?
    !!built_in
  end

  def name
    return attributes["entity_name"] unless built_in?

    attribute_key = attributes["entity_name"].parameterize(separator: "_")
    return model_attribute(self, attribute_key).upcase if I18n.exists?("activerecord.attributes.entity.#{attribute_key}")

    attributes["entity_name"]
  end

  def update_card_transactions_count_and_total
    update_columns(card_transactions_count: card_transactions.count, card_transactions_total: card_transactions.sum(:price))
  end

  def update_cash_transactions_count_and_total
    update_columns(cash_transactions_count: cash_transactions.count, cash_transactions_total: cash_transactions.sum(:price))
  end

  # @protected_instance_methods ...............................................
  protected

  def set_built_in
    self.built_in ||= false
  end

  def prevent_deactivation_when_built_in
    return unless built_in?
    return unless will_save_change_to_active?
    return if active?

    errors.add(:active, :cannot_deactivate_built_in)
  end

  def prevent_destroy_when_built_in
    return unless built_in?

    errors.add(:base, :cannot_destroy_built_in)
    throw :abort
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: entities
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  avatar_name             :string           default("people/0.png"), not null
#  built_in                :boolean          default(FALSE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  entity_name             :string           not null, uniquely indexed => [user_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  entity_user_id          :bigint           indexed
#  user_id                 :bigint           not null, indexed, uniquely indexed => [entity_name]
#
# Indexes
#
#  index_entities_on_entity_user_id    (entity_user_id)
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (entity_user_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
