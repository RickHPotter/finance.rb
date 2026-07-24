# frozen_string_literal: true

class HealthCheck::NamingConventions::Analysis
  attr_reader :context, :records, :user

  def initialize(user:, context:, records: nil)
    @user = user
    @context = context
    @records = records
  end

  def call(dry_run:)
    Linter::NamingService.new(
      cash_transactions: records || naming_scope,
      user:,
      dry_run:,
      locale: user.locale
    ).call
  end

  def naming_scope
    context.cash_transactions
           .order(:id)
           .includes(
             :user,
             :categories,
             :card_installments,
             { investments: %i[investment_type user_bank_account] },
             { exchanges: { entity_transaction: %i[entity transactable] } }
           )
  end
end
