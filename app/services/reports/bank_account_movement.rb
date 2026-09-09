# frozen_string_literal: true

module Reports
  class BankAccountMovement
    FAMILIES = %i[ordinary transfer failed_transfer piggy_bank generated_card_payment generated_investment].freeze

    attr_reader :context, :user_bank_account, :query_state

    def initialize(context:, user_bank_account:, query_state:)
      @context = context
      @user_bank_account = user_bank_account
      @query_state = query_state
    end

    def call
      rows = selected_rows

      {
        query: query_state.canonical_params,
        resource: resource_payload,
        summary: aggregate_payload(rows),
        payment_states: payment_state_payloads,
        balance_context: balance_context_payload,
        buckets: bucket_payloads(rows),
        breakdowns: family_payloads(rows)
      }
    end

    private

    def all_rows
      @all_rows ||= CanonicalRows.new(
        context:,
        query_state: base_query_state,
        cash_relation: account_installments,
        card_relation: nil
      ).call
    end

    def account_installments
      context.cash_installments.joins(:cash_transaction).where(cash_transactions: { user_bank_account_id: user_bank_account.id })
    end

    def base_query_state
      @base_query_state ||= QueryState.new(query_state.canonical_params.merge(paid_state: "all", direction: "all"))
    end

    def direction_rows
      @direction_rows ||= all_rows.select do |row|
        case query_state.direction
        when "income" then row.amount_cents.positive?
        when "outcome" then row.amount_cents.negative?
        else true
        end
      end
    end

    def selected_rows
      @selected_rows ||= direction_rows.select do |row|
        case query_state.paid_state
        when "paid" then row.paid?
        when "pending" then !row.paid?
        else true
        end
      end
    end

    def resource_payload
      {
        type: user_bank_account.class.name,
        id: user_bank_account.id,
        label: user_bank_account.user_bank_account_name
      }
    end

    def aggregate_payload(rows)
      income_rows = rows.select { |row| row.amount_cents.positive? }
      outcome_rows = rows.select { |row| row.amount_cents.negative? }

      {
        income: metric_payload(income_rows),
        outcome: metric_payload(outcome_rows),
        net_cents: rows.sum(&:amount_cents)
      }
    end

    def metric_payload(rows)
      {
        amount_cents: rows.sum { |row| row.amount_cents.abs },
        source_count: rows.size,
        sources: Drilldowns.new(rows:, return_to: source_dashboard_path).call
      }
    end

    def payment_state_payloads
      %i[paid pending].map do |state|
        rows = direction_rows.select { |row| row.paid? == (state == :paid) }
        {
          key: state,
          label: I18n.t("reports.bank_account_movement.payment_states.#{state}"),
          **aggregate_payload(rows)
        }
      end
    end

    def bucket_payloads(rows)
      rows_by_period = rows.group_by(&:period_key)

      query_state.periods.map do |period|
        key = query_state.granularity == "day" ? period.iso8601 : period.strftime("%Y-%m")
        { key:, **aggregate_payload(rows_by_period.fetch(key, [])) }
      end
    end

    def family_payloads(rows)
      rows_by_family = rows.group_by(&:movement_family)

      FAMILIES.filter_map do |family|
        family_rows = rows_by_family[family]
        next if family_rows.blank?

        {
          key: family,
          label: I18n.t("reports.bank_account_movement.families.#{family}"),
          **aggregate_payload(family_rows)
        }
      end
    end

    def balance_context_payload
      ordered = all_rows.select { |row| row.balance_cents.present? }.sort_by do |row|
        [ row.installment.order_id || Float::INFINITY, row.occurred_on, row.installment_id ]
      end

      {
        account_balance_cents: user_bank_account.balance.to_i,
        recorded_count: ordered.size,
        first_recorded: recorded_balance_payload(ordered.first),
        latest_recorded: recorded_balance_payload(ordered.last)
      }
    end

    def recorded_balance_payload(row)
      return if row.blank?

      {
        amount_cents: row.balance_cents,
        occurred_on: row.occurred_on.iso8601,
        installment_id: row.installment_id,
        order_id: row.installment.order_id
      }
    end

    def source_dashboard_path
      @source_dashboard_path ||= Rails.application.routes.url_helpers.user_bank_account_path(user_bank_account, query_state.canonical_params)
    end
  end
end
