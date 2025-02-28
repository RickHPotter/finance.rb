# frozen_string_literal: true

class Budget < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  has_many :budget_categories
  has_many :categories, through: :budget_categories
  has_many :budget_entities
  has_many :entities, through: :budget_entities

  # @validations ..............................................................
  validates :month, :year, presence: true
  validates :budget_value, presence: true, numericality: { lesser_than_or_equal_to: 0 }
  validates :remaining_value, presence: true, numericality: { lesser_than_or_equal_to: 0 }
  validates :inclusive, inclusion: { in: [ true, false ] }

  # @callbacks ................................................................
  before_create :set_remaining_value
  before_update :update_budget_according_to_changes

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def set_remaining_value
    category_ids = budget_categories.map(&:category_id)
    entity_ids = budget_entities.map(&:entity_id)

    cash_installments = user.cash_installments.where(month:, year:)
    card_installments = user.card_installments.where(month:, year:)

    if inclusive
      cash_installments.by_categories_and_entities(category_ids, entity_ids) + card_installments.by_categories_and_entities(category_ids, entity_ids)
    else
      cash_installments.by_categories_or_entities(category_ids, entity_ids) + card_installments.by_categories_or_entities(category_ids, entity_ids)
    end => installments

    self.remaining_value = budget_value - installments.sum(&:price)
  end

  # @protected_instance_methods ...............................................

  protected

  def update_budget_according_to_changes
    if budget_value_changed?
      self.remaining_value += changes[:budget_value].last - changes[:budget_value].first
    elsif inclusive_changed? || month_changed? || year_changed? || user_id_changed? || changes.without(:remaining_value).empty?
      set_remaining_value
    end
  end

  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: budgets
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  budget_value    :integer          not null
#  inclusive       :boolean          default(TRUE), not null
#  month           :integer          not null
#  remaining_value :integer          not null
#  year            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null, indexed
#
# Indexes
#
#  index_budgets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
