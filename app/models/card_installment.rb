# frozen_string_literal: true

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
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
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
class CardInstallment < Installment
  # @extends ..................................................................
  delegate :user, :user_id, :user_card, :user_card_id, to: :card_transaction, allow_nil: true

  # @includes .................................................................
  include CashTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :card_transaction, counter_cache: true

  # @validations ..............................................................
  validates :card_installments_count, presence: true

  # @callbacks ................................................................
  before_validation :set_installment_type, on: :create
  before_validation :set_paid,             on: :create

  # @scopes ...................................................................
  default_scope { where(installment_type: :CardInstallment) }
  scope :by, ->(month:, year:, user_id:, user_card_id:) { joins(:card_transaction).where(month:, year:, card_transaction: { user_id:, user_card_id: }) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # Generates a `date` for the associated `cash_transaction`, picking the `current_due_date` of `user_card` based on the `current_closing_date`.
  #
  # @return [Date].
  #
  def cash_transaction_date
    card_transaction.cash_transaction_date.next_month(number - 1)
  end

  # @protected_instance_methods ...............................................

  protected

  # Generates a `description` for the associated `cash_transaction` based on the `user_card` name and `month_year`.
  #
  # @return [String] The generated description.
  #
  def description
    "CARD PAYMENT [ #{user_card.user_card_name} - #{month_year} ]"
  end

  # Generates a `comment` for the associated `cash_transaction` based on the `user_card` and `month` and `year`.
  #
  # @return [String] The generated comment.
  #
  def comment
    installments = CardInstallment.by(month:, year:, user_id:, user_card_id:)

    x, y = installments.partition { |installment| installment.card_installments_count == 1 }
    in_one = x.sum(&:price).round(2)
    spread = y.sum(&:price).round(2)

    "Upfront: #{in_one}, Installments: #{spread}"
  end

  # Generates a `category_transactions` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions
    { category_id: user.built_in_category("CARD PAYMENT").id }
  end

  # Generates a `category_transactions_attributes` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def category_transactions_attributes
    [ category_transactions.merge(id: nil) ]
  end

  # Generates a `entity_transactions_attributes` for the associated `cash_transaction` that mounts up the card invoice.
  #
  # @return [Hash] The generated attributes.
  #
  def entity_transactions_attributes
    [ { id: nil, is_payer: false, price: 0, entity_id: user.entities.find_or_create_by(entity_name: user_card.user_card_name).id } ]
  end

  # @private_instance_methods .................................................

  private

  def set_installment_type
    self.installment_type = :CardInstallment
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
