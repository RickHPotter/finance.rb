# frozen_string_literal: true

module FiscalReceipts
  class AccessKey
    LENGTH = 44
    SUPPORTED_MODELS = %w[55 65].freeze

    attr_reader :value

    def initialize(value)
      @value = value.to_s.gsub(/\s/, "")
    end

    def valid?
      value.match?(/\A\d{44}\z/) && SUPPORTED_MODELS.include?(model) && check_digit == value[-1].to_i
    end

    def state_code
      value[0, 2]
    end

    def model
      value[20, 2]
    end

    private

    def check_digit
      weighted_sum = value[0, LENGTH - 1].reverse.chars.each_with_index.sum do |digit, index|
        digit.to_i * ((index % 8) + 2)
      end
      remainder = weighted_sum % 11
      remainder < 2 ? 0 : 11 - remainder
    end
  end
end
