# frozen_string_literal: true

class Category < ApplicationRecord
  COLOUR_HEX_PATTERN = /\A#[0-9a-f]{6}\z/

  # @extends ..................................................................
  # @includes .................................................................
  include HasActive
  include TranslateHelper
  include FinancialAuditable

  audits_financial_changes skip: %i[card_transactions_count card_transactions_total cash_transactions_count cash_transactions_total], on: %i[destroy]

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :parent_category, class_name: "Category", optional: true
  has_many :subcategories, class_name: "Category", foreign_key: :parent_category_id, dependent: :restrict_with_error, inverse_of: :parent_category

  has_many :category_transactions, dependent: :destroy
  has_many :card_transactions, through: :category_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :cash_transactions, through: :category_transactions, source: :transactable, source_type: "CashTransaction"
  has_many :investments, through: :category_transactions, source: :transactable, source_type: "Investment"

  # @validations ..............................................................
  validates :category_name, presence: true, uniqueness: { scope: %i[user_id parent_category_id] }
  validates :colour, presence: true
  validates :colour, format: { with: COLOUR_HEX_PATTERN }, allow_blank: true
  validates :built_in, inclusion: { in: [ true, false ] }
  validates :text_colour, presence: true, if: :text_colour_manual?
  validates :text_colour, format: { with: COLOUR_HEX_PATTERN }, allow_blank: true, if: :text_colour_manual?
  validate :manual_text_colour_has_sufficient_contrast
  validate :validate_hierarchy_depth
  validate :validate_parent_ownership
  validate :validate_built_in_hierarchy
  validate :validate_active_state_matches_parent

  # @callbacks ................................................................
  before_validation :set_built_in, :normalize_colour_values
  after_update :cascade_deactivation, if: -> { saved_change_to_active? && !active? }

  # @scopes ...................................................................
  scope :built_in, -> { where(built_in: true) }
  scope :top_level, -> { where(parent_category_id: nil) }
  scope :subcategories, -> { where.not(parent_category_id: nil) }
  scope :parents, -> { where(id: select(:parent_category_id).where.not(parent_category_id: nil)) }
  scope :leaves, -> { where.not(id: select(:parent_category_id).where.not(parent_category_id: nil)) }

  # @additional_config ........................................................
  enum :text_colour_mode, { automatic: "automatic", manual: "manual" }, default: :automatic, prefix: :text_colour, validate: true

  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # @return [Boolean].
  #
  def built_in?
    built_in
  end

  def hex_colour
    colour
  end

  def resolved_text_colour
    colour_contrast&.foreground
  end

  def colour_contrast_ratio
    colour_contrast&.ratio
  end

  def name
    return model_attribute(self, attributes["category_name"].parameterize(separator: "_")).upcase if built_in?

    attributes["category_name"]
  end

  def update_card_transactions_count_and_total
    update_columns(card_transactions_count: card_transactions.count, card_transactions_total: card_transactions.sum(:price))
  end

  def update_cash_transactions_count_and_total
    update_columns(cash_transactions_count: cash_transactions.count, cash_transactions_total: cash_transactions.sum(:price))
  end

  def parent?
    subcategories.any?
  end

  def subcategory?
    parent_category_id.present?
  end

  def standalone?
    !parent? && !subcategory?
  end

  def subtree_ids
    [ id ] + subcategory_ids
  end

  def rollup_card_transactions_count
    card_transactions_count + subcategories.sum(:card_transactions_count)
  end

  def rollup_card_transactions_total
    card_transactions_total + subcategories.sum(:card_transactions_total)
  end

  def rollup_cash_transactions_count
    cash_transactions_count + subcategories.sum(:cash_transactions_count)
  end

  def rollup_cash_transactions_total
    cash_transactions_total + subcategories.sum(:cash_transactions_total)
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets `built_in` in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_built_in
    self.built_in ||= false
  end

  # @private_instance_methods .................................................

  private

  def normalize_colour_values
    self.colour = normalize_colour(colour)

    if text_colour_automatic?
      self.text_colour = nil
    elsif text_colour.present?
      self.text_colour = normalize_colour(text_colour)
    end
  end

  def normalize_colour(value)
    CategoryColours::Contrast.normalize(value)
  rescue CategoryColours::Contrast::InvalidColour
    value
  end

  def manual_text_colour_has_sufficient_contrast
    return unless text_colour_manual?

    assessment = colour_contrast
    return if assessment.nil? || assessment.passing?

    errors.add(
      :text_colour,
      :insufficient_contrast,
      ratio: assessment.ratio_label,
      minimum: "#{Kernel.format('%.2f', CategoryColours::Contrast::MINIMUM_RATIO)}:1",
      suggestion: assessment.suggested_foreground
    )
  end

  def colour_contrast
    contrast = CategoryColours::Contrast.new(colour)
    text_colour_manual? ? contrast.assess(text_colour) : contrast.automatic_assessment
  rescue CategoryColours::Contrast::InvalidColour
    nil
  end

  def validate_hierarchy_depth
    return if parent_category_id.blank?

    if parent_category_id == id
      errors.add(:parent_category_id, :cannot_be_self)
    elsif parent_category&.subcategory?
      errors.add(:parent_category_id, :cannot_be_child_of_child)
    elsif subcategories.any?
      errors.add(:parent_category_id, :cannot_have_parent_when_has_children)
    end
  end

  def validate_parent_ownership
    return if parent_category_id.blank?

    return unless parent_category && parent_category.user_id != user_id

    errors.add(:parent_category_id, :must_belong_to_same_user)
  end

  def validate_built_in_hierarchy
    if built_in? && parent_category_id.present?
      errors.add(:parent_category_id, :built_in_cannot_have_parent)
    elsif parent_category&.built_in?
      errors.add(:parent_category_id, :built_in_cannot_be_parent)
    end
  end

  def validate_active_state_matches_parent
    return if parent_category_id.blank? || !active?

    return unless parent_category && !parent_category.active?

    errors.add(:active, :cannot_be_active_when_parent_inactive)
  end

  def cascade_deactivation
    subcategories.update_all(active: false)
  end
end

# == Schema Information
#
# Table name: categories
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  built_in                :boolean          default(FALSE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  category_name           :string           not null, uniquely indexed => [user_id, parent_category_id]
#  colour                  :string           default("#f1f5f9"), not null
#  text_colour             :string
#  text_colour_mode        :string           default("automatic"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  parent_category_id      :bigint           indexed, uniquely indexed => [user_id, category_name]
#  user_id                 :bigint           not null, indexed, uniquely indexed => [parent_category_id, category_name]
#
# Indexes
#
#  index_categories_on_parent_category_id       (parent_category_id)
#  index_categories_on_user_id                  (user_id)
#  index_categories_on_user_id_parent_and_name  (user_id,parent_category_id,category_name) UNIQUE NULLS NOT DISTINCT
#
# Foreign Keys
#
#  fk_rails_...  (parent_category_id => categories.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id)
#
