# frozen_string_literal: true

class Budget < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :flag_for_balance_recalculation

  # @relationships ............................................................
  belongs_to :user
  has_many :budget_categories, dependent: :destroy
  has_many :categories, through: :budget_categories
  has_many :budget_entities, dependent: :destroy
  has_many :entities, through: :budget_entities

  accepts_nested_attributes_for :budget_categories, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :budget_entities, allow_destroy: true, reject_if: :all_blank

  # @validations ..............................................................
  validates :month, :year, presence: true
  validates :value, :starting_value, presence: true, numericality: { lesser_than_or_equal_to: 0 }
  validates :inclusive, inclusion: { in: [ true, false ] }

  # @callbacks ................................................................
  before_validation :set_starting_value
  before_save :set_remaining_value
  before_save :set_flag_for_balance_recalculation
  after_commit :trigger_balance_recalculation, on: %i[create update], if: :flag_for_balance_recalculation

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def date
    Date.new(year, month).beginning_of_month
  end

  def set_starting_value
    self.starting_value ||= value
  end

  def set_remaining_value
    category_ids = budget_categories.map(&:category_id)
    entity_ids = budget_entities.map(&:entity_id)

    cash_installments = user.cash_installments.where(month:, year:)
    card_installments = user.card_installments.where(month:, year:)

    if inclusive && category_ids.present? && entity_ids.present?
      inclusive_installments(cash_installments, card_installments, category_ids, entity_ids)
    else
      exclusive_installments(cash_installments, card_installments, category_ids, entity_ids)
    end => installments

    installments_price = installments.sum(&:price)
    self.value = [ value, installments_price ].min
    self.remaining_value = value - installments_price
  end

  def inclusive_installments(cash_installments, card_installments, category_ids, entity_ids)
    cash_installments.by_categories_and_entities(category_ids, entity_ids) + card_installments.by_categories_and_entities(category_ids, entity_ids)
  end

  def exclusive_installments(cash_installments, card_installments, category_ids, entity_ids)
    if category_ids.present? && entity_ids.present?
      cash_installments.by_categories_or_entities(category_ids, entity_ids) + card_installments.by_categories_or_entities(category_ids, entity_ids)
    elsif category_ids.present?
      cash_installments.by_categories(category_ids) + card_installments.by_categories(category_ids)
    elsif entity_ids.present?
      cash_installments.by_entities(entity_ids) + card_installments.by_entities(entity_ids)
    end
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def set_flag_for_balance_recalculation
    self.flag_for_balance_recalculation = changes.slice(:price, :remaining_value, :month, :year).present?
  end

  def trigger_balance_recalculation
    Logic::RecalculateBalancesService.new(user:, year:, month:).call
  end
end

# == Schema Information
#
# Table name: budgets
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  balance         :integer
#  description     :string           not null
#  inclusive       :boolean          default(TRUE), not null
#  month           :integer          not null
#  remaining_value :integer          not null
#  starting_value  :integer          not null
#  value           :integer          not null
#  year            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  order_id        :integer          indexed
#  user_id         :bigint           not null, indexed
#
# Indexes
#
#  idx_budgets_order_id      (order_id)
#  index_budgets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
