# frozen_string_literal: true

class Budget < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasActive

  # @security (i.e. attr_accessible) ..........................................
  attr_accessor :recalculate_balance

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
  validate :presence_of_categories_or_entities, if: -> { errors.empty? }
  validate :uniqueness_of_budget, if: -> { errors.empty? }

  # @callbacks ................................................................
  before_validation :set_starting_value, :set_inclusive
  before_save :set_remaining_value
  before_save :set_recalculate_balance
  after_commit :update_cash_balance, if: -> { recalculate_balance || destroyed? }

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

  def set_inclusive
    return if [ false, true ].include?(inclusive)

    self.inclusive = false
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

    installments_price = total_price_without_exchanges(installments)

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

  def total_price_without_exchanges(installments)
    installments.map do |installment|
      paying_entity_transactions  = installment.transactable.entity_transactions.where(exchanges_count: 1..)
      installment_exchanges_price = paying_entity_transactions.map(&:exchanges).flatten.select { |e| e.year == year && e.month == month }.sum(&:price) * -1

      installment.price - installment_exchanges_price
    end.sum
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def set_recalculate_balance
    return if [ false, true ].include?(recalculate_balance)

    self.recalculate_balance = changes.slice(:price, :remaining_value, :month, :year).present?
  end

  def update_cash_balance
    Logic::RecalculateBalancesService.new(user:, year:, month:).call and return if destroyed?

    Logic::RecalculateBalancesService.new(user:, year: changes[:year]&.min || year, month: changes[:month]&.min || month).call
  end

  def presence_of_categories_or_entities
    return if budget_categories.present? || budget_entities.present?

    errors.add(:base, I18n.t("activerecord.errors.models.budget.missing_categories_or_entities"))
  end

  def uniqueness_of_budget # rubocop:disable Metrics/AbcSize
    current_ref_month_year_budgets = user.budgets.where(month:, year:)
    return if current_ref_month_year_budgets.empty?

    category_ids = budget_categories.map(&:category_id)
    entity_ids = budget_entities.map(&:entity_id)

    if inclusive
      same_budget = current_ref_month_year_budgets.joins(:categories, :entities).where(categories: { id: category_ids }, entities: { id: entity_ids })
      return if same_budget.empty?
      return if same_budget.pluck(:id) == [ id ]

      errors.add(:base, I18n.t("activerecord.errors.models.budget.same_budget"))
    else
      same_category = current_ref_month_year_budgets.joins(:categories).where(categories: { id: category_ids })
      same_entity = current_ref_month_year_budgets.joins(:entities).where(entities: { id: entity_ids })

      error_messages = []
      error_messages << I18n.t("activerecord.errors.models.budget.same_category_budget") if same_category.present? && same_category.pluck(:id) != [ id ]
      error_messages << I18n.t("activerecord.errors.models.budget.same_entity_budget") if same_entity.present? && same_entity.pluck(:id) != [ id ]

      errors.add(:base, error_messages.join(" ")) if error_messages.present?
    end
  end
end

# == Schema Information
#
# Table name: budgets
# Database name: primary
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  balance         :integer
#  description     :string           not null
#  inclusive       :boolean          default(FALSE), not null
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
