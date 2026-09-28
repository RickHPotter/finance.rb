# frozen_string_literal: true

class LineItem < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include CategoryTransactable
  include EntityTransactable
  include FinancialAuditable

  audits_financial_changes

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :skip_category_presence_validation

  # @relationships ............................................................
  belongs_to :transactable, polymorphic: true, touch: true

  # @validations ..............................................................
  validates :description, presence: true
  validates :price, presence: true, numericality: { other_than: 0 }
  validate :validate_category_presence
  validate :validate_leaf_category
  validate :validate_price_sign_matches_parent

  # @callbacks ................................................................
  before_validation :sync_entity_transaction_price

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  delegate :user, :context, to: :transactable, allow_nil: true

  def category_id
    category_transactions.reject(&:marked_for_destruction?).first&.category_id
  end

  def category_id=(id)
    if id.blank?
      category_transactions.each(&:mark_for_destruction)
      return
    end

    int_id = id.to_i
    active = category_transactions.reject(&:marked_for_destruction?)
    if active.any?
      active.first.category_id = int_id
      active[1..]&.each(&:mark_for_destruction)
    else
      category_transactions.build(category_id: int_id)
    end
  end

  def category
    category_transactions.reject(&:marked_for_destruction?).first&.category
  end

  def category=(cat)
    self.category_id = cat&.id
  end

  def entity_id
    entity_transactions.reject(&:marked_for_destruction?).first&.entity_id
  end

  def entity_id=(id)
    if id.blank?
      entity_transactions.each(&:mark_for_destruction)
      return
    end

    int_id = id.to_i
    active = entity_transactions.reject(&:marked_for_destruction?)
    if active.any?
      active.first.entity_id = int_id
      active.first.price = price.to_i
      active[1..]&.each(&:mark_for_destruction)
    else
      entity_transactions.build(entity_id: int_id, price: price.to_i)
    end
  end

  def entity
    entity_transactions.reject(&:marked_for_destruction?).first&.entity
  end

  def entity=(ent)
    self.entity_id = ent&.id
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
  private

  def sync_entity_transaction_price
    entity_transactions.reject(&:marked_for_destruction?).each do |et|
      et.price = price.to_i
    end
  end

  def validate_category_presence
    return if skip_category_presence_validation

    errors.add(:category_id, :blank) if category_id.blank?
  end

  def validate_leaf_category
    return if category_id.blank?

    cat = Category.find_by(id: category_id)
    return if cat.nil?

    errors.add(:category_id, :must_be_leaf_category) if cat.parent?
  end

  def validate_price_sign_matches_parent
    return if price.blank? || transactable.blank? || transactable.price.blank?

    if transactable.price.positive? && price.negative?
      errors.add(:price, :must_be_positive_to_match_transaction)
    elsif transactable.price.negative? && price.positive?
      errors.add(:price, :must_be_negative_to_match_transaction)
    end
  end
end

# == Schema Information
#
# Table name: line_items
# Database name: primary
#
#  id                :bigint           not null, primary key
#  comment           :text
#  description       :string           not null
#  price             :integer          default(0), not null
#  transactable_type :string           not null, indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  transactable_id   :bigint           not null, indexed => [transactable_type]
#
# Indexes
#
#  index_line_items_on_transactable_type_and_transactable_id  (transactable_type,transactable_id)
#
