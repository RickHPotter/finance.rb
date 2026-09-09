# frozen_string_literal: true

module Reports
  class QueryState
    GRANULARITIES = %w[day month].freeze
    PAID_STATES = %w[all paid pending].freeze
    DIRECTIONS = %w[all income outcome].freeze
    SORTS = %w[date_asc date_desc amount_asc amount_desc].freeze
    MAX_DAY_RANGE = 93
    MAX_MONTH_RANGE = 24

    class InvalidState < ArgumentError
      attr_reader :code

      def initialize(code)
        @code = code
        super(I18n.t("reports.errors.#{code}"))
      end
    end

    attr_reader :from_date, :to_date, :granularity, :paid_state, :direction, :sort

    def initialize(params = {}, today: Time.zone.today, allowed_sorts: SORTS, default_sort: "date_asc")
      @params = params.to_h.with_indifferent_access
      @today = today.to_date
      @allowed_sorts = allowed_sorts.map(&:to_s).freeze
      @default_sort = default_sort.to_s

      validate_configuration!
      resolve!
    end

    def apply(relation)
      relation = apply_range(relation)
      relation = apply_paid_state(relation)
      apply_direction(relation)
    end

    def canonical_params
      {
        from_date: from_date.iso8601,
        to_date: to_date.iso8601,
        granularity:,
        paid_state:,
        direction:,
        sort:
      }
    end

    def occurred_on(installment)
      return installment.date.in_time_zone.to_date if granularity == "day"

      Date.new(installment.year, installment.month, 1)
    end

    def period_key(installment)
      date = occurred_on(installment)
      granularity == "day" ? date.iso8601 : date.strftime("%Y-%m")
    end

    def periods
      return (from_date..to_date).to_a if granularity == "day"

      first = from_date.beginning_of_month
      last = to_date.beginning_of_month
      Enumerator.produce(first, &:next_month).take_while { |date| date <= last }
    end

    private

    attr_reader :params, :today, :allowed_sorts, :default_sort

    def resolve!
      @to_date = parse_date(params[:to_date]) || today.end_of_month
      @from_date = parse_date(params[:from_date]) || to_date.beginning_of_month.prev_month(11)
      @granularity = enum_value(:granularity, GRANULARITIES, "month")
      @paid_state = enum_value(:paid_state, PAID_STATES, "all")
      @direction = enum_value(:direction, DIRECTIONS, "all")
      @sort = enum_value(:sort, allowed_sorts, default_sort)

      validate_range!
    end

    def parse_date(value)
      return if value.blank?

      string = value.to_s
      raise InvalidState, :invalid_date unless string.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Date.iso8601(string)
    rescue Date::Error
      raise InvalidState, :invalid_date
    end

    def enum_value(key, allowed, default)
      value = params[key].presence&.to_s || default
      raise InvalidState, :"invalid_#{key}" unless value.in?(allowed)

      value
    end

    def validate_configuration!
      raise ArgumentError, "default sort must be allowlisted" unless default_sort.in?(allowed_sorts)
      raise ArgumentError, "at least one sort must be allowlisted" if allowed_sorts.empty?
    end

    def validate_range!
      raise InvalidState, :invalid_range if from_date > to_date

      range_size = if granularity == "day"
                     (to_date - from_date).to_i + 1
                   else
                     ((to_date.year * 12) + to_date.month) - ((from_date.year * 12) + from_date.month) + 1
                   end
      maximum = granularity == "day" ? MAX_DAY_RANGE : MAX_MONTH_RANGE
      raise InvalidState, :range_too_large if range_size > maximum
    end

    def apply_range(relation)
      if granularity == "day"
        relation.where(date: from_date.beginning_of_day..to_date.end_of_day)
      else
        first_month = (from_date.year * 12) + from_date.month
        last_month = (to_date.year * 12) + to_date.month
        relation.where("(installments.year * 12 + installments.month) BETWEEN ? AND ?", first_month, last_month)
      end
    end

    def apply_paid_state(relation)
      case paid_state
      when "paid" then relation.where(paid: true)
      when "pending" then relation.where(paid: false)
      else relation
      end
    end

    def apply_direction(relation)
      case direction
      when "income" then relation.where("installments.price > 0")
      when "outcome" then relation.where("installments.price < 0")
      else relation
      end
    end
  end
end
