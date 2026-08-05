# frozen_string_literal: true

class Entity < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :friendship, optional: true

  has_many :entity_transactions, dependent: :destroy
  has_many :card_transactions, through: :entity_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :cash_transactions, through: :entity_transactions, source: :transactable, source_type: "CashTransaction"

  # @validations ..............................................................
  validates :entity_name, presence: true, uniqueness: { scope: :user_id }
  validates :built_in, inclusion: { in: [ true, false ] }
  validate :prevent_deactivation_when_built_in

  # @callbacks ................................................................
  before_validation :assign_friendship_if_needed
  before_validation :set_built_in
  before_destroy :prevent_destroy_when_built_in

  # @scopes ...................................................................
  scope :built_in, -> { where(built_in: true) }
  scope :that_are_users, -> { where.not(friendship_id: nil) }
  scope :where_entity_user_id, ->(id) { joins(:friendship).where("friendships.user_id = :id OR friendships.friend_id = :id", id: id) }
  scope :where_entity_user, ->(user) { where_entity_user_id(user.id) }
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def built_in?
    !!built_in
  end

  def name
    if friendship_id?
      other_user = friendship.user_id == user_id ? friendship.friend : friendship.user
      display_name = other_user&.profile&.display_name
      return "#{attributes["entity_name"]} [#{display_name}]" if display_name
    end

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

  def entity_user_id
    if has_attribute?(:entity_user_id) && read_attribute(:entity_user_id).present?
      read_attribute(:entity_user_id)
    elsif has_attribute?(:friendship_id) && friendship_id?
      friendship.user_id == user_id ? friendship.friend_id : friendship.user_id
    else
      nil
    end
  end

  def entity_user_id=(id)
    return if id.blank?

    friend_user = User.find(id)
    self.entity_user = friend_user
  end

  def entity_user
    if has_attribute?(:entity_user_id) && read_attribute(:entity_user_id).present?
      User.find_by(id: read_attribute(:entity_user_id))
    elsif has_attribute?(:friendship_id) && friendship_id?
      friendship.user_id == user_id ? friendship.friend : friendship.user
    else
      nil
    end
  end

  attr_accessor :entity_user_to_assign

  def entity_user=(friend_user)
    @entity_user_to_assign = friend_user
  end

  # @protected_instance_methods ...............................................
  protected

  def assign_friendship_if_needed
    return unless @entity_user_to_assign.present?

    user_id_val = user&.id || user_id
    friend_id_val = @entity_user_to_assign.id

    existing = nil
    existing = Friendship.where(user_id: [ user_id_val, friend_id_val ], friend_id: [ user_id_val, friend_id_val ]).first if user_id_val && friend_id_val

    self.friendship = existing || Friendship.new(user: user, friend: @entity_user_to_assign)
    @entity_user_to_assign = nil
  end

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
#  friendship_id           :bigint           indexed
#  user_id                 :bigint           not null, indexed, uniquely indexed => [entity_name]
#
# Indexes
#
#  index_entities_on_friendship_id     (friendship_id)
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (friendship_id => friendships.id)
#  fk_rails_...  (user_id => users.id)
#
