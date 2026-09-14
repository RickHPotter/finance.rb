# frozen_string_literal: true

module Logic
  class References
    COMBINE_INTO_TARGET = "combine_into_target"
    REALLOCATE_INSTALLMENTS = "reallocate_installments"
    MERGE_MODES = [ COMBINE_INTO_TARGET, REALLOCATE_INSTALLMENTS ].freeze

    # rubocop:disable Naming/PredicateMethod
    def self.merge(user_card, source_reference_date, target_reference_date, merge_mode:, context: user_card.user.main_context,
                   historical_correction_confirmation: false)
      merge_result(
        user_card,
        source_reference_date,
        target_reference_date,
        merge_mode:,
        context:,
        historical_correction_confirmation:
      ).applied?
    end

    def self.merge_result(user_card, source_reference_date, target_reference_date, merge_mode:, context: user_card.user.main_context,
                          historical_correction_confirmation: false)
      merge_mode = merge_mode.to_s

      return ReferenceMerges::Result.rejected(:invalid_mode) unless merge_mode.in?(MERGE_MODES)

      source_date = normalize_date(source_reference_date)
      target_date = normalize_date(target_reference_date)

      return ReferenceMerges::Result.rejected(:invalid_date) unless source_date && target_date

      return reallocation_result(user_card, source_date, target_date, context:, historical_correction_confirmation:) if merge_mode == REALLOCATE_INSTALLMENTS

      ReferenceMerges::CombineApply.new(
        user_card:,
        context:,
        source_date:,
        target_date:,
        historical_correction_confirmation:
      ).call
    end

    def self.normalize_date(value)
      value = Date.parse(value.to_s) unless value.respond_to?(:to_date)
      value.to_date.beginning_of_month
    rescue ArgumentError, TypeError
      nil
    end
    private_class_method :normalize_date

    def self.reallocation_result(user_card, source_date, target_date, context:, historical_correction_confirmation:)
      plan = ReferenceMerges::ReallocationPlanner.new(
        user_card:,
        context:,
        source_date:,
        target_date:,
        historical_correction_confirmation:
      ).call

      ReferenceMerges::ReallocationApply.new(plan:).call
    end
    # rubocop:enable Naming/PredicateMethod
  end
end
