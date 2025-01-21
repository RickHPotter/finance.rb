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
