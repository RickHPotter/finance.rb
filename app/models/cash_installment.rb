# frozen_string_literal: true

class CashInstallment < Installment
  # @extends ..................................................................
  delegate :user, :user_id, :user_card, :user_card_id, to: :cash_transaction, allow_nil: true

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  def balance = @balance || read_attribute("balance")
  attr_writer :balance

  # @relationships ............................................................
  belongs_to :cash_transaction, counter_cache: true

  # @validations ..............................................................
  validates :cash_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_installment_type, :set_paid, on: :create
  after_save :check_paid_situation

  # @scopes ...................................................................
  default_scope { where(installment_type: :CashInstallment) }
  scope :by_categories, ->(categories) { joins(cash_transaction: :categories).where(cash_transaction: { categories: }) }
  scope :by_entities, ->(entities) { joins(cash_transaction: :entities).where(cash_transaction: { entities: }) }
  scope :by_categories_and_entities, ->(categories, entities) { joins(cash_transaction: %i[categories entities]).where(cash_transaction: { categories:, entities: }) }
  scope :by_categories_or_entities, lambda { |categories, entities|
    joins(cash_transaction: %i[categories entities]).where(cash_transaction: { categories: }).or(
      joins(cash_transaction: %i[categories entities]).where(cash_transaction: { entities: })
    )
  }

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
    return if [ false, true ].include?(paid)

    self.paid = date.present? && Date.current >= date
  end

  # Sets `cash_transaction.paid` as true if all its installments were paid.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def check_paid_situation
    cash_transaction.update_columns(paid: cash_transaction.cash_installments.where(paid: false).empty?)
  end
end

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :datetime         not null
#  date_month              :integer          not null, indexed => [date_year]
#  date_year               :integer          not null, indexed => [date_month]
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
#
# Indexes
#
#  idx_installments_price                     (price)
#  idx_installments_year_month                (date_year,date_month)
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
