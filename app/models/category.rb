# frozen_string_literal: true

class Category < ApplicationRecord
  COLOUR_HEX_PATTERN = /\A#[0-9a-f]{6}\z/

  # @extends ..................................................................
  # @includes .................................................................
  include HasActive
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  has_many :category_transactions, dependent: :destroy
  has_many :card_transactions, through: :category_transactions, source: :transactable, source_type: "CardTransaction"
  has_many :cash_transactions, through: :category_transactions, source: :transactable, source_type: "CashTransaction"
  has_many :investments, through: :category_transactions, source: :transactable, source_type: "Investment"

  # @validations ..............................................................
  validates :category_name, presence: true, uniqueness: { scope: :user_id }
  validates :colour, presence: true
  validates :colour, format: { with: COLOUR_HEX_PATTERN }, allow_blank: true
  validates :built_in, inclusion: { in: [ true, false ] }
  validates :text_colour, presence: true, if: :text_colour_manual?
  validates :text_colour, format: { with: COLOUR_HEX_PATTERN }, allow_blank: true, if: :text_colour_manual?
  validate :manual_text_colour_has_sufficient_contrast

  # @callbacks ................................................................
  before_validation :set_built_in, :normalize_colour_values

  # @scopes ...................................................................
  scope :built_in, -> { where(built_in: true) }

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
#  category_name           :string           not null, uniquely indexed => [user_id]
#  colour                  :string           default("#f1f5f9"), not null
#  text_colour             :string
#  text_colour_mode        :string           default("automatic"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed, uniquely indexed => [category_name]
#
# Indexes
#
#  index_categories_on_user_id           (user_id)
#  index_category_name_on_composite_key  (user_id,category_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
