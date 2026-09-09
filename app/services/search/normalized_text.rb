# frozen_string_literal: true

module Search
  class NormalizedText
    IDENTIFIER_PATTERN = /\A[a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)?\z/

    class << self
      def apply(scope, term, *columns)
        condition = condition_for(term, *columns)
        condition ? scope.where(condition) : scope
      end

      def condition_for(term, *columns)
        normalized_term = normalize(term)
        return if normalized_term.blank?

        predicates = columns.map { |column| "#{normalized_sql(column)} LIKE :normalized_search_term" }
        [ predicates.join(" OR "), { normalized_search_term: "%#{ActiveRecord::Base.sanitize_sql_like(normalized_term)}%" } ]
      end

      def normalize(value)
        value.to_s.unicode_normalize(:nfkd)
             .gsub(/\p{Mn}/, "")
             .downcase
             .squish
      end

      private

      def normalized_sql(column)
        identifier = column.to_s
        raise ArgumentError, "Invalid search column: #{identifier}" unless identifier.match?(IDENTIFIER_PATTERN)

        quoted_column = identifier.split(".").map { |part| connection.quote_column_name(part) }.join(".")
        "btrim(regexp_replace(lower(unaccent(coalesce(#{quoted_column}::text, ''))), E'\\\\s+', ' ', 'g'))"
      end

      def connection
        ApplicationRecord.connection
      end
    end
  end
end
