# frozen_string_literal: true

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
  before_validation :set_installment_type, :set_paid, on: :create
  after_save :check_paid_situation

  # @scopes ...................................................................
  default_scope { where(installment_type: :CardInstallment) }
  scope :by_categories, ->(categories) { joins(card_transaction: :categories).where(card_transaction: { categories: }) }
  scope :by_entities, ->(entities) { joins(card_transaction: :entities).where(card_transaction: { entities: }) }
  scope :by_categories_and_entities, ->(categories, entities) { joins(card_transaction: %i[categories entities]).where(card_transaction: { categories:, entities: }) }
  scope :by_categories_or_entities, lambda { |categories, entities|
    joins(card_transaction: %i[categories entities]).where(card_transaction: { categories: }).or(
      joins(card_transaction: %i[categories entities]).where(card_transaction: { entities: })
    )
  }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  # Retrieves the `reference_date` for the associated `cash_transaction` through `user_card.references`, based on `month` and `year`.
  #
  # @return [Date].
  #
  def card_payment_date
    reference_date = (card_transaction.date + (number - 1).months).end_of_month
    user_card.references.create_with(reference_date:).find_or_create_by(month: reference_date.month, year: reference_date.year).reference_date
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
    installments = user_card.card_installments.where(month:, year:)

    x, y = installments.partition { |installment| installment.card_installments_count == 1 }
    in_one = x.sum(&:price)
    spread = y.sum(&:price)

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
    return if [ false, true ].include?(paid)

    self.paid = date.present? && Date.current >= date
  end

  # Sets `card_transaction.paid` as true if all its installments were paid.
  #
  # @note This is a method that is called after_save.
  #
  # @return [void].
  #
  def check_paid_situation
    card_transaction.update_columns(paid: card_transaction.card_installments.where(paid: false).empty?)
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
