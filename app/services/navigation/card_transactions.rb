# frozen_string_literal: true

module Navigation
  class CardTransactions
    QUERY_SCHEMA = {
      active_month_years: :scalar_or_array,
      all_month_years: :scalar,
      default_year: :scalar,
      direction: :scalar,
      exchange_bound_type: :scalar,
      force_mobile: :scalar,
      from_ct_price: :scalar,
      from_installments_count: :scalar,
      from_installments_number: :scalar,
      from_price: :scalar,
      order_by: :scalar,
      search_term: :scalar,
      sort: :scalar,
      to_ct_price: :scalar,
      to_installments_count: :scalar,
      to_installments_number: :scalar,
      to_price: :scalar,
      user_card_id: :scalar,
      card_transaction: {
        card_installment_ids: :scalar_or_array,
        category_id: :scalar_or_array,
        entity_id: :scalar_or_array,
        user_card_id: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:, current_context:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ card_transactions_path, search_card_transactions_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: {
          "user_card_id" => current_user.user_cards,
          "card_transaction.card_installment_ids" => current_context.card_installments,
          "card_transaction.category_id" => current_user.categories,
          "card_transaction.entity_id" => current_user.entities,
          "card_transaction.user_card_id" => current_user.user_cards
        }
      )
    end

    private

    def card_transactions_path
      Rails.application.routes.url_helpers.card_transactions_path
    end

    def search_card_transactions_path
      Rails.application.routes.url_helpers.search_card_transactions_path
    end
  end
end
