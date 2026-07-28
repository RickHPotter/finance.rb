# frozen_string_literal: true

module Navigation
  class UserBankAccounts
    QUERY_SCHEMA = {
      search_term: :scalar,
      user_bank_account: {
        id: :scalar_or_array,
        status: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ Rails.application.routes.url_helpers.user_bank_accounts_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: { "user_bank_account.id" => current_user.user_bank_accounts }
      )
    end
  end
end
