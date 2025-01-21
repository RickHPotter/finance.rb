# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  starting_price          :integer          not null
#  price                   :integer          not null
#  number                  :integer          not null
#  month                   :integer          not null
#  year                    :integer          not null
#  installment_type        :string           not null
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class Installment < ApplicationRecord
  # @extends ..................................................................

  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  # @validations ..............................................................
  validates :price, :number, :month, :year, :card_installments_count, :cash_installments_count, :installment_type, presence: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # Builds `month` and `year` columns for `self`.
  #
  # @return [void].
  #
  def build_month_year
    set_month_year
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
