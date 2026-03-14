# frozen_string_literal: true

class InvestmentType < ApplicationRecord
  # @relationships ............................................................
  has_many :investments, dependent: :nullify
  has_many :cash_transactions, dependent: :nullify

  # @validations ..............................................................
  validates :investment_type_name_fallback, presence: true
  validates :investment_type_code, uniqueness: true, allow_nil: true

  def display_name
    return investment_type_name_fallback if investment_type_code.blank?

    I18n.t("activerecord.attributes.investment_type.#{investment_type_code}", default: investment_type_name_fallback)
  end
end

# == Schema Information
#
# Table name: investment_types
# Database name: primary
#
#  id                            :bigint           not null, primary key
#  built_in                      :boolean          default(FALSE), not null, indexed
#  investment_type_code          :string           uniquely indexed
#  investment_type_name_fallback :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_investment_types_on_built_in              (built_in)
#  index_investment_types_on_investment_type_code  (investment_type_code) UNIQUE
#
