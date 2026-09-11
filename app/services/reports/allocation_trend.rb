# frozen_string_literal: true

module Reports
  class AllocationTrend
    DIMENSIONS = %i[category entity].freeze

    attr_reader :context, :anchor, :dimension, :query_state

    def initialize(context:, anchor:, dimension:, query_state:)
      @context = context
      @anchor = anchor
      @dimension = dimension.to_sym
      @query_state = query_state

      raise ArgumentError, "unsupported allocation trend dimension" unless dimension.in?(DIMENSIONS)
    end

    def call
      rows = source_rows

      {
        query: query_state.canonical_params,
        resource: resource_payload,
        summary: aggregate_payload(rows),
        buckets: bucket_payloads(rows),
        breakdowns: breakdown_payloads(rows)
      }
    end

    private

    def source_rows
      @source_rows ||= CanonicalRows.new(context:, query_state:).call.select do |row|
        row.movement_family == :ordinary && anchor_allocated?(row.transaction)
      end
    end

    def anchor_allocated?(transaction)
      allocations_for(transaction, dimension).any? { |record| record.id == anchor.id }
    end

    def resource_payload
      {
        type: anchor.class.name,
        id: anchor.id,
        label: anchor.name
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

    def bucket_payloads(rows)
      rows_by_period = rows.group_by(&:period_key)

      query_state.periods.map do |period|
        key = query_state.granularity == "day" ? period.iso8601 : period.strftime("%Y-%m")
        { key:, **aggregate_payload(rows_by_period.fetch(key, [])) }
      end
    end

    def breakdown_payloads(rows)
      grouped = rows.group_by { |row| bundle_for(row.transaction) }

      entries = grouped.map do |bundle, bundle_rows|
        {
          **bundle,
          **aggregate_payload(bundle_rows)
        }
      end

      entries.sort_by { |entry| [ -(entry.dig(:income, :amount_cents) + entry.dig(:outcome, :amount_cents)), entry[:label], entry[:key] ] }
    end

    def bundle_for(transaction)
      records = allocations_for(transaction, counterpart_dimension).sort_by { |record| [ record.name, record.id ] }
      return unassigned_bundle if records.empty?

      bundle = {
        key: "#{counterpart_dimension.to_s.pluralize}:#{records.pluck(:id).join('+')}",
        label: records.map(&:name).join(" + ")
      }
      return bundle unless counterpart_dimension == :category

      bundle.merge(CategoryColours::Presentation.bundle(records).chart_payload)
    end

    def unassigned_bundle
      bundle = {
        key: "#{counterpart_dimension}:unassigned",
        label: I18n.t("balances.monthly_analysis.unassigned")
      }
      return bundle unless counterpart_dimension == :category

      bundle.merge(CategoryColours::Presentation.neutral.chart_payload)
    end

    def allocations_for(transaction, allocation_dimension)
      allocation_dimension == :category ? transaction.categories : transaction.entities
    end

    def counterpart_dimension
      dimension == :category ? :entity : :category
    end

    def source_dashboard_path
      @source_dashboard_path ||= begin
        routes = Rails.application.routes.url_helpers
        params = query_state.canonical_params
        dimension == :category ? routes.category_path(anchor, params) : routes.entity_path(anchor, params)
      end
    end
  end
end
