# frozen_string_literal: true

AllocationMutations::Outcome = Data.define(:status, :owner_type, :owner_id, :reason_code, :details) do
  class << self
    def eligible(owner:, reason_code: :ready, details: {})
      build(:eligible, owner:, reason_code:, details:)
    end

    def noop(owner:, reason_code:, details: {})
      build(:noop, owner:, reason_code:, details:)
    end

    def conflict(owner:, reason_code:, details: {})
      build(:conflict, owner:, reason_code:, details:)
    end

    private

    def build(status, owner:, reason_code:, details:)
      new(status:, owner_type: owner.class.base_class.name, owner_id: owner.id, reason_code:, details:)
    end
  end

  def initialize(status:, owner_type:, owner_id:, reason_code:, details: {})
    status = status.to_s.to_sym
    owner_type = owner_type.to_s
    owner_id = Integer(owner_id, exception: false)
    reason_code = reason_code.to_s.to_sym

    raise ArgumentError, "unsupported allocation outcome: #{status}" unless status.in?(self.class::STATUSES)
    raise ArgumentError, "owner type is required" if owner_type.blank?
    raise ArgumentError, "owner id is required" unless owner_id&.positive?
    raise ArgumentError, "reason code is required" if reason_code.blank?
    raise ArgumentError, "details must be a hash" unless details.respond_to?(:to_h)

    super(status:, owner_type:, owner_id:, reason_code:, details: details.to_h.deep_symbolize_keys.freeze)
  end

  def eligible?
    status == :eligible
  end

  def noop?
    status == :noop
  end

  def conflict?
    status == :conflict
  end
end

AllocationMutations::Outcome::STATUSES = %i[eligible noop conflict].freeze
