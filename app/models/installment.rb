# frozen_string_literal: true

class Installment < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include HasMonthYear
  include HasStartingPrice

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  # @validations ..............................................................
  validates :number, :installment_type, presence: true

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

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :date             not null
#  installment_type        :string           not null
#  month                   :integer          not null
#  number                  :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_transaction_id     :bigint           indexed
#  cash_transaction_id     :bigint           indexed
#
# Indexes
#
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
