# frozen_string_literal: true

module Reports
  class UserCardMovement
    FAMILIES = %i[ordinary advance transfer failed_transfer piggy_bank].freeze

    attr_reader :context, :user_card, :query_state

    def initialize(context:, user_card:, query_state:)
      @context = context
      @user_card = user_card
      @query_state = query_state
    end

    def call
      rows = selected_rows

      {
        query: query_state.canonical_params,
        resource: resource_payload,
        summary: aggregate_payload(rows),
        payment_states: payment_state_payloads,
        buckets: bucket_payloads(rows),
        breakdowns: family_payloads(rows),
        details: detail_payloads(rows)
      }
    end

    private

    def all_rows
      @all_rows ||= CanonicalRows.new(
        context:,
        query_state: base_query_state,
        cash_relation: nil,
        card_relation: card_installments
      ).call
    end

    def card_installments
      context.card_installments.joins(:card_transaction).where(card_transactions: { user_card_id: user_card.id })
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
        type: user_card.class.name,
        id: user_card.id,
        label: user_card.user_card_name
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
          label: I18n.t("reports.user_card_movement.payment_states.#{state}"),
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
      rows_by_family = rows.group_by { |row| report_family(row) }

      FAMILIES.filter_map do |family|
        family_rows = rows_by_family[family]
        next if family_rows.blank?

        {
          key: family,
          label: I18n.t("reports.user_card_movement.families.#{family}"),
          **aggregate_payload(family_rows)
        }
      end
    end

    def report_family(row)
      return :advance if advance?(row.transaction)

      row.movement_family
    end

    def advance?(transaction)
      transaction.advance_cash_transaction_id.present? || transaction.categories.any? { |category| category.category_name == "CARD ADVANCE" }
    end

    def detail_payloads(rows)
      rows.map do |row|
        transaction = row.transaction
        installment = row.installment
        reference = references_by_period[[ installment.year, installment.month ]]

        {
          identity: { installment_type: row.installment_type, installment_id: row.installment_id },
          transaction_id: row.transaction_id,
          description: transaction.description,
          amount_cents: row.amount_cents,
          paid: row.paid?,
          family: report_family(row),
          purchase_date: transaction.date.to_date.iso8601,
          installment_date: installment.date.to_date.iso8601,
          installment_number: installment.number,
          billing_period: format("%<year>04d-%<month>02d", year: installment.year, month: installment.month),
          invoice: reference_payload(reference, installment),
          generated_payment: { cash_transaction_id: installment.cash_transaction_id },
          advance: { active: advance?(transaction), cash_transaction_id: transaction.advance_cash_transaction_id },
          path: exact_source_path(row)
        }
      end
    end

    def reference_payload(reference, installment)
      {
        reference_id: reference&.id,
        month: installment.month,
        year: installment.year,
        closing_date: reference&.reference_closing_date&.iso8601,
        due_date: reference&.reference_date&.iso8601
      }
    end

    def references_by_period
      @references_by_period ||= user_card.references.where(context:).index_by { |reference| [ reference.year, reference.month ] }
    end

    def exact_source_path(row)
      Drilldowns.new(rows: [ row ], return_to: source_dashboard_path).call.dig(:card, :chunks, 0, :path)
    end

    def source_dashboard_path
      @source_dashboard_path ||= Rails.application.routes.url_helpers.user_card_path(user_card, query_state.canonical_params)
    end
  end
end
