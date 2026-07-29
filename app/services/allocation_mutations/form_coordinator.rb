# frozen_string_literal: true

class AllocationMutations::FormCoordinator
  Error = Data.define(:code, :details)

  GENERATED_CATEGORY_BY_TYPE = {
    "CardInstallment" => "CARD PAYMENT",
    "CardTransaction" => "CARD ADVANCE",
    "Exchange" => "EXCHANGE RETURN",
    "Investment" => "INVESTMENT",
    "PiggyBank" => "PIGGY BANK RETURN"
  }.freeze

  attr_reader :owner, :entity_attributes, :errors

  def initialize(owner:, entity_attributes: nil)
    @owner = owner
    @entity_attributes = entity_attributes
    @errors = []
  end

  def call
    validate_supported_owner
    return self if errors.any?

    validate_allocation_ownership
    validate_entity_replacement_representation
    validate_generated_category
    validate_subscription_allocations
    self
  end

  def valid?
    errors.empty?
  end

  private

  def validate_supported_owner
    add_error(:unsupported_allocation_owner) unless owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction)
  end

  def validate_allocation_ownership
    return if owner.user.blank?

    add_error(:allocation_category_not_owned, ids: foreign_category_ids) if foreign_category_ids.any?
    add_error(:allocation_entity_not_owned, ids: foreign_entity_ids) if foreign_entity_ids.any?
  end

  def validate_entity_replacement_representation
    changed_ids = submitted_entity_attributes.filter_map do |attributes|
      next if destroy?(attributes)

      allocation_id = integer_id(attributes[:id])
      submitted_entity_id = integer_id(attributes[:entity_id])
      next if allocation_id.blank? || submitted_entity_id.blank?

      persisted_entity_id = persisted_entity_ids[allocation_id]
      allocation_id if persisted_entity_id.present? && persisted_entity_id != submitted_entity_id
    end

    add_error(:entity_replacement_requires_destroy_and_add, ids: changed_ids) if changed_ids.any?
  end

  def validate_generated_category
    return unless owner.is_a?(CashTransaction) && owner.persisted?

    required_name = GENERATED_CATEGORY_BY_TYPE[owner.cash_transaction_type]
    return if required_name.blank?
    return unless persisted_category_names.include?(required_name)
    return if active_category_names.include?(required_name)

    add_error(:generated_allocation_category_required, category: required_name)
  end

  def validate_subscription_allocations
    return unless owner.persisted?
    return if owner.subscription_allocation_sync
    return if owner.original_categories.nil? && owner.original_entities.nil?
    return unless allocation_membership_changed?

    subscription = owner.subscription
    return if subscription.blank?
    return unless subscription_managed_allocation?(subscription)

    subscription_category_id = owner.user.built_in_category("SUBSCRIPTION")&.id
    required_category_ids = [ *subscription.category_ids, subscription_category_id ].compact.uniq
    required_entity_ids = subscription.entity_ids
    return if (required_category_ids - active_category_ids).empty? && (required_entity_ids - active_entity_ids).empty?

    add_error(:subscription_allocation_managed)
  end

  def subscription_managed_allocation?(subscription)
    subscription_category_id = owner.user.built_in_category("SUBSCRIPTION")&.id
    persisted_categories = CategoryTransaction.where(transactable: owner).pluck(:category_id)
    persisted_entities = persisted_entity_ids.values

    persisted_categories.include?(subscription_category_id) ||
      persisted_categories.intersect?(subscription.category_ids) ||
      persisted_entities.intersect?(subscription.entity_ids)
  end

  def allocation_membership_changed?
    original_category_ids = owner.original_categories.nil? ? active_category_ids : Array(owner.original_categories).map(&:to_i).sort
    original_entity_ids = owner.original_entities.nil? ? active_entity_ids : Array(owner.original_entities).map(&:to_i).sort

    original_category_ids != active_category_ids.sort || original_entity_ids != active_entity_ids.sort
  end

  def foreign_category_ids
    active_category_ids - owner.user.categories.where(id: active_category_ids).ids
  end

  def foreign_entity_ids
    active_entity_ids - owner.user.entities.where(id: active_entity_ids).ids
  end

  def active_category_ids
    @active_category_ids ||= owner.category_transactions.reject(&:marked_for_destruction?).filter_map(&:category_id).map(&:to_i).uniq
  end

  def active_entity_ids
    @active_entity_ids ||= owner.entity_transactions.reject(&:marked_for_destruction?).filter_map(&:entity_id).map(&:to_i).uniq
  end

  def active_category_names
    owner.user.categories.where(id: active_category_ids).pluck(:category_name)
  end

  def persisted_category_names
    Category.joins(:category_transactions)
            .where(category_transactions: { transactable: owner })
            .pluck(:category_name)
  end

  def persisted_entity_ids
    @persisted_entity_ids ||= EntityTransaction.where(transactable: owner).pluck(:id, :entity_id).to_h
  end

  def submitted_entity_attributes
    @submitted_entity_attributes ||= normalize_nested_attributes(entity_attributes)
  end

  def normalize_nested_attributes(attributes)
    raw_attributes = attributes.respond_to?(:to_unsafe_h) ? attributes.to_unsafe_h : attributes

    case raw_attributes
    when Hash
      collection = raw_attributes.keys.all? { |key| key.to_s.match?(/\A\d+\z/) } ? raw_attributes.values : [ raw_attributes ]
      collection.map(&:with_indifferent_access)
    else
      Array(raw_attributes).map(&:with_indifferent_access)
    end
  end

  def destroy?(attributes)
    ActiveModel::Type::Boolean.new.cast(attributes[:_destroy])
  end

  def integer_id(value)
    Integer(value, exception: false)
  end

  def add_error(code, details = {})
    errors << Error.new(code:, details: details.freeze)
  end
end
