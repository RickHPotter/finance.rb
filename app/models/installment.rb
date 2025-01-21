# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  number                  :integer          not null
#  date                    :date             not null
#  month                   :integer          not null
#  year                    :integer          not null
#  starting_price          :integer          not null
#  price                   :integer          not null
#  paid                    :boolean          default(FALSE)
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
  validates :number, :date, :month, :year, :price, :installment_type, presence: true
  validates :paid, inclusion: { in: [ true, false ] }

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
