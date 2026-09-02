# frozen_string_literal: true

module Navigation
  class CashTransactions
    QUERY_SCHEMA = {
      active_month_years: :scalar_or_array,
      all_month_years: :scalar,
      attach_to_subscription_id: :scalar,
      default_year: :scalar,
      direction: :scalar,
      exchange_bound_type: :scalar,
      force_mobile: :scalar,
      full_month_counts: :scalar,
      from_ct_price: :scalar,
      from_date: :scalar,
      from_installments_count: :scalar,
      from_installments_number: :scalar,
      from_price: :scalar,
      paid: :scalar,
      paid_state: :scalar,
      pending: :scalar,
      search_term: :scalar,
      skip_budgets: :scalar,
      sort: :scalar,
      to_ct_price: :scalar,
      to_date: :scalar,
      to_installments_count: :scalar,
      to_installments_number: :scalar,
      to_price: :scalar,
      cash_transaction: {
        cash_installment_ids: :scalar_or_array,
        category_id: :scalar_or_array,
        entity_id: :scalar_or_array,
        id: :scalar_or_array,
        subscription_id: :scalar_or_array,
        user_bank_account_id: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:, current_context:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ fallback ],
        query_schema: QUERY_SCHEMA,
        id_scopes: {
          "cash_transaction.cash_installment_ids" => current_context.cash_installments,
          "cash_transaction.category_id" => current_user.categories,
          "cash_transaction.entity_id" => current_user.entities,
          "cash_transaction.id" => current_context.cash_transactions,
          "cash_transaction.subscription_id" => current_context.subscriptions,
          "cash_transaction.user_bank_account_id" => current_user.user_bank_accounts,
          "attach_to_subscription_id" => current_context.subscriptions
        }
      )
    end
  end
end
