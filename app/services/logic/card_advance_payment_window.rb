# frozen_string_literal: true

module Logic
  class CardAdvancePaymentWindow
    attr_reader :user_card, :context, :cycle_date, :minimum, :maximum

    def initialize(user_card:, context:, month:, year:)
      @user_card = user_card
      @context = context
      @cycle_date = Date.new(Integer(year), Integer(month), 1)

      load_boundaries
    rescue ArgumentError, TypeError
      @cycle_date = nil
      @minimum = nil
      @maximum = nil
    end

    def available?
      cycle_date.present? && (minimum.present? || maximum.present?)
    end

    def cover?(datetime)
      moment = normalize_datetime(datetime)
      return false unless available? && moment.present?
      return false if minimum.present? && moment < minimum
      return false if maximum.present? && moment > maximum

      true
    end

    def default_datetime(now: Time.zone.now)
      moment = normalize_datetime(now)
      return moment if minimum.present? && maximum.present? && moment.between?(minimum, maximum)

      maximum
    end

    private

    def load_boundaries
      references = user_card.references.where(context:)
      previous_reference = references.find_by_month_year(cycle_date.prev_month)
      current_reference = references.find_by_month_year(cycle_date)

      @minimum = local_midnight(previous_reference&.reference_closing_date)
      @maximum = local_midnight(current_reference&.reference_date)
    end

    def local_midnight(value)
      return if value.blank?

      Time.zone.local(value.year, value.month, value.day)
    end

    def normalize_datetime(value)
      return if value.blank?

      value.in_time_zone.change(sec: 0, usec: 0)
    rescue ArgumentError, NoMethodError
      nil
    end
  end
end
