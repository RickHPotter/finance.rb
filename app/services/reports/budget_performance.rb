# frozen_string_literal: true

module Reports
  class BudgetPerformance
    attr_reader :budget, :today

    def initialize(budget:, today: Time.zone.today)
      @budget = budget
      @today = today
    end

    def call
      entries = matching_entries
      actual_cents = entries.sum(&:amount_cents)

      {
        resource: resource_payload,
        definition: definition_payload,
        performance: performance_payload(actual_cents),
        rules: rules_payload,
        sources: source_payload(entries)
      }
    end

    private

    def matching_entries
      @matching_entries ||= Logic::BudgetMatching.new(budget:).call
    end

    def resource_payload
      { type: budget.class.name, id: budget.id, label: budget.description }
    end

    def definition_payload
      {
        amount_cents: budget.starting_value.to_i,
        current_limit_cents: budget.value.to_i,
        recorded_remaining_cents: budget.remaining_value.to_i,
        active: budget.active?,
        period: {
          starts_on: period_start.iso8601,
          ends_on: period_end.iso8601,
          key: period_start.strftime("%Y-%m")
        }
      }
    end

    def performance_payload(actual_cents)
      remaining_cents = budget.starting_value.to_i - actual_cents

      {
        actual_cents:,
        remaining_cents:,
        utilization_percentage: percentage(actual_cents.abs, budget.starting_value.to_i.abs),
        period_completion_percentage:,
        status: performance_status(remaining_cents)
      }
    end

    def performance_status(remaining_cents)
      return "exceeded" if remaining_cents.positive?
      return "exact" if remaining_cents.zero?

      "available"
    end

    def rules_payload
      {
        inclusive: budget.inclusive?,
        first_installment_only: budget.first_installment_only?,
        allocation_operator: budget.inclusive? ? "all" : "any",
        category_ids: budget.budget_categories.filter_map(&:category_id).uniq.sort,
        entity_ids: budget.budget_entities.filter_map(&:entity_id).uniq.sort
      }
    end

    def source_payload(entries)
      drilldowns = Drilldowns.new(rows: entries, return_to: source_dashboard_path).call

      %i[cash card].index_with do |type|
        type_name = type == :cash ? "CashInstallment" : "CardInstallment"
        rows = entries.select { |entry| entry.installment_type == type_name }.sort_by(&:installment_id)
        source = drilldowns.fetch(type)
        source.merge(
          amount_cents: rows.sum(&:amount_cents),
          chunks: signed_chunks(source.fetch(:chunks), rows)
        )
      end
    end

    def signed_chunks(chunks, rows)
      chunks.each_with_index.map do |chunk, index|
        chunk_rows = rows.slice(index * Drilldowns::CHUNK_SIZE, chunk.fetch(:count))
        chunk.merge(amount_cents: chunk_rows.sum(&:amount_cents))
      end
    end

    def percentage(numerator, denominator)
      return 0.0 if denominator.zero?

      (numerator.fdiv(denominator) * 100).round(2)
    end

    def period_completion_percentage
      return 0.0 if today < period_start
      return 100.0 if today > period_end

      percentage((today - period_start).to_i + 1, (period_end - period_start).to_i + 1)
    end

    def period_start
      @period_start ||= Date.new(budget.year, budget.month, 1)
    end

    def period_end
      @period_end ||= period_start.end_of_month
    end

    def source_dashboard_path
      @source_dashboard_path ||= Rails.application.routes.url_helpers.budget_path(budget)
    end
  end
end
