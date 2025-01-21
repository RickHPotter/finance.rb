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
class CashInstallment < Installment
  # @extends ..................................................................
  delegate :user, :user_id, :user_card, :user_card_id, :date, to: :cash_transaction, allow_nil: true

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :cash_transaction, counter_cache: true

  # @validations ..............................................................
  # @callbacks ................................................................
  before_validation :set_installment_type, on: :create

  # @scopes ...................................................................
  default_scope { where(installment_type: :cash) }
  scope :by, ->(month:, year:, user_id:) { joins(:cash_transaction).where(month:, year:, cash_transaction: { user_id: }) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def set_installment_type
    self.installment_type = :cash
  end
end
