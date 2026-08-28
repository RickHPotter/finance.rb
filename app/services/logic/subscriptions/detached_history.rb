# frozen_string_literal: true

module Logic
  module Subscriptions
    class DetachedHistory
      LIMIT = 100
      RECORD_TYPES = %w[CashTransaction CardTransaction].freeze
      SUBSCRIPTION_MATCH_SQL = <<~SQL.squish.freeze
        audit_versions.metadata ->> 'subscription_id' = :subscription_id
        OR audit_versions.object ->> 'subscription_id' = :subscription_id
        OR audit_versions.object_changes -> 'subscription_id' ->> 0 = :subscription_id
        OR audit_versions.object_changes -> 'subscription_id' ->> 1 = :subscription_id
      SQL
      CURRENTLY_DETACHED_SQL = <<~SQL.squish.freeze
        (
          audit_versions.item_type = 'CashTransaction'
          AND (
            current_cash_transactions.id IS NULL
            OR (
              current_cash_transactions.context_id = :context_id
              AND current_cash_transactions.subscription_id IS DISTINCT FROM :current_subscription_id
            )
          )
        )
        OR (
          audit_versions.item_type = 'CardTransaction'
          AND (
            current_card_transactions.id IS NULL
            OR (
              current_card_transactions.context_id = :context_id
              AND current_card_transactions.subscription_id IS DISTINCT FROM :current_subscription_id
            )
          )
        )
      SQL

      Entry = Data.define(:record_type, :item_id, :record, :description, :date, :price, :detached_at) do
        def live? = record.present?

        def destroyed? = !live?
      end

      attr_reader :subscription

      def self.call(subscription:)
        new(subscription:).call
      end

      def initialize(subscription:)
        @subscription = subscription
      end

      def call
        evidence_versions = bounded_evidence_versions
        return [] if evidence_versions.empty?

        records = current_records(evidence_versions)
        latest_versions = latest_versions_for(evidence_versions)

        entries = evidence_versions.filter_map do |evidence|
          build_entry(evidence, records:, latest_versions:)
        end
        entries.sort_by { |entry| entry_order(entry) }
      end

      private

      def bounded_evidence_versions
        deduplicated = matching_versions
                       .select("DISTINCT ON (audit_versions.item_type, audit_versions.item_id) audit_versions.*")
                       .order(Arel.sql("audit_versions.item_type ASC, audit_versions.item_id ASC, audit_versions.created_at DESC, audit_versions.id DESC"))

        AuditVersion.from("(#{deduplicated.to_sql}) audit_versions")
                    .order(created_at: :desc, item_type: :asc, item_id: :asc, id: :desc)
                    .limit(LIMIT)
                    .to_a
      end

      def matching_versions
        authorized_versions
          .joins(<<~SQL.squish)
            LEFT JOIN cash_transactions current_cash_transactions
              ON audit_versions.item_type = 'CashTransaction'
              AND current_cash_transactions.id = audit_versions.item_id
          SQL
          .joins(<<~SQL.squish)
            LEFT JOIN card_transactions current_card_transactions
              ON audit_versions.item_type = 'CardTransaction'
              AND current_card_transactions.id = audit_versions.item_id
          SQL
          .where(SUBSCRIPTION_MATCH_SQL, subscription_id: subscription.id.to_s)
          .where(CURRENTLY_DETACHED_SQL, context_id: subscription.context_id, current_subscription_id: subscription.id)
      end

      def authorized_versions
        AuditVersion.where(
          owner_id: subscription.user_id,
          context_id: subscription.context_id,
          item_type: RECORD_TYPES
        )
      end

      def current_records(evidence_versions)
        RECORD_TYPES.to_h do |record_type|
          ids = evidence_versions.filter_map { |version| version.item_id if version.item_type == record_type }
          model = record_type.constantize
          [ record_type, model.where(id: ids).index_by(&:id) ]
        end
      end

      def latest_versions_for(evidence_versions)
        condition = identity_condition(evidence_versions)
        return {} if condition.blank?

        authorized_versions
          .where(condition)
          .select("DISTINCT ON (audit_versions.item_type, audit_versions.item_id) audit_versions.*")
          .order(Arel.sql("audit_versions.item_type ASC, audit_versions.item_id ASC, audit_versions.created_at DESC, audit_versions.id DESC"))
          .index_by { |version| [ version.item_type, version.item_id ] }
      end

      def identity_condition(evidence_versions)
        table = AuditVersion.arel_table

        conditions = RECORD_TYPES.filter_map do |record_type|
          ids = evidence_versions.filter_map { |version| version.item_id if version.item_type == record_type }
          table[:item_type].eq(record_type).and(table[:item_id].in(ids)) if ids.present?
        end
        conditions.reduce { |condition, part| condition.or(part) }
      end

      def build_entry(evidence, records:, latest_versions:)
        record = records.fetch(evidence.item_type).fetch(evidence.item_id, nil)
        return if record.present? && record.context_id != subscription.context_id
        return if record&.subscription_id == subscription.id

        state = record.present? ? record.attributes : historical_state(latest_versions.fetch([ evidence.item_type, evidence.item_id ], evidence))

        Entry.new(
          record_type: evidence.item_type,
          item_id: evidence.item_id,
          record:,
          description: state["description"],
          date: parsed_date(state["date"]),
          price: state["price"]&.to_i,
          detached_at: evidence.created_at
        )
      end

      def historical_state(version)
        return version.object.to_h if version.event_destroy?

        version.object_changes.to_h.each_with_object(version.object.to_h.deep_dup) do |(attribute, values), state|
          state[attribute] = Array(values).last
        end
      end

      def parsed_date(value)
        Time.zone.parse(value.to_s) if value.present?
      rescue ArgumentError, TypeError
        nil
      end

      def entry_order(entry)
        effective_date = entry.date || entry.detached_at || Time.zone.at(0)
        [ -effective_date.to_time.to_i, entry.record_type, entry.item_id ]
      end
    end
  end
end
