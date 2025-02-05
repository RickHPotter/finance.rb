# frozen_string_literal: true

class CashInstallment < Installment
  # @extends ..................................................................
  delegate :user, :user_id, :user_card, :user_card_id, to: :cash_transaction, allow_nil: true

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :cash_transaction, counter_cache: true

  # @validations ..............................................................
  validates :cash_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_installment_type, on: :create
  before_validation :set_paid,             on: :create

  # @scopes ...................................................................
  default_scope { where(installment_type: :CashInstallment) }
  scope :by, ->(month:, year:, user_id:) { joins(:cash_transaction).where(month:, year:, cash_transaction: { user_id: }) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def set_installment_type
    self.installment_type = :CashInstallment
  end

  # Sets `paid` based on current `date` in case it was not previously set, on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_paid
    return if paid.present?

    self.paid = date.present? && Date.current >= date
  end
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
