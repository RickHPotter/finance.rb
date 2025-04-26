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
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  balance                 :integer
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :datetime         not null, indexed => [date_year, date_month]
#  date_month              :integer          not null, indexed => [date_year, date]
#  date_year               :integer          not null, indexed => [date_month, date]
#  installment_type        :string           not null
#  month                   :integer          not null
#  number                  :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null, indexed
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_transaction_id     :bigint           indexed
#  cash_transaction_id     :bigint           indexed
#  order_id                :integer          indexed
#
# Indexes
#
#  idx_installments_order_id                  (order_id)
#  idx_installments_price                     (price)
#  idx_installments_year_month_date           (date_year,date_month,date)
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
