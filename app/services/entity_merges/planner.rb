# frozen_string_literal: true

# Validates eligibility and projects the impact of merging two entities.
#
# Follows the KAKASHI-18 entity merge contract, providing conflict detection
# for monetary, payer, exchange, piggy bank, and structural conflicts.
# Supports both :strict and :eligible_only modes.
class EntityMerges::Planner
  VALID_MODES = %i[strict eligible_only].freeze

  attr_reader :actor, :context, :source_id, :destination_id, :mode

  def initialize(actor:, context:, source_id:, destination_id:, mode:)
    @actor = actor
    @context = context
    @source_id = source_id.to_i
    @destination_id = destination_id.to_i
    @mode = mode&.to_sym
  end

  def call
    return conflict(:context_not_owned) unless context&.user_id == actor.id
    return conflict(:invalid_mode) unless mode.in?(VALID_MODES)
    return noop(:same_entity) if source_id == destination_id

    err = validate_entities
    return err if err

    err = validate_friend_guard
    return err if err

    plan
  end

  private

  # --- Top-level Validation ---------------------------------------------------

  def validate_entities
    return conflict(:source_not_found)      if source.blank?
    return conflict(:destination_not_found) if destination.blank?
    return conflict(:source_inactive)       unless source.active?
    return conflict(:destination_inactive)  unless destination.active?
    return conflict(:source_protected)      if source.built_in?
    return conflict(:destination_protected) if destination.built_in?

    nil
  end

  def validate_friend_guard
    return unless source.friendship_id.present? || destination.friendship_id.present?
    return conflict(:cross_user_friend_entity) unless source.entity_user_id.present? && source.entity_user_id == destination.entity_user_id

    nil
  end

  # --- Row Classification -----------------------------------------------------

  def plan
    transfer_rows = []
    collapse_rows = []
    conflict_rows = []

    classify_entity_transactions(transfer_rows, collapse_rows, conflict_rows)
    classify_budget_entities(transfer_rows, collapse_rows, conflict_rows)

    EntityMerges::Plan.new(
      actor:,
      context:,
      source:,
      destination:,
      mode:,
      outcome: :eligible,
      transfer_rows:,
      collapse_rows:,
      conflict_rows:
    )
  end

  def classify_entity_transactions(transfer, collapse, conflict)
    source.entity_transactions.includes(:exchanges, :transactable).find_each do |entity_transaction|
      destination_row = destination_transaction(entity_transaction)
      policy_conflict = conflict_for(entity_transaction, destination_row:)
      if policy_conflict
        conflict << row_plan(entity_transaction, :conflict, policy_conflict.fetch(:reason_code), policy_conflict.fetch(:details, {}))
      elsif destination_row
        collapse << row_plan(entity_transaction, :collapse, nil, row_details(entity_transaction, destination_row_id: destination_row.id))
      else
        transfer << row_plan(entity_transaction, :transfer, nil, row_details(entity_transaction))
      end
    end
  end

  def classify_budget_entities(transfer, collapse, conflict)
    BudgetEntity.where(entity: source).includes(:budget).find_each do |budget_entity|
      destination_row = destination_budget_entity(budget_entity)
      policy_conflict = conflict_for(budget_entity, destination_row:)
      if policy_conflict
        conflict << row_plan(budget_entity, :conflict, policy_conflict.fetch(:reason_code), policy_conflict.fetch(:details, {}))
      elsif destination_row
        collapse << row_plan(budget_entity, :collapse, nil, row_details(budget_entity, destination_row_id: destination_row.id))
      else
        transfer << row_plan(budget_entity, :transfer, nil, row_details(budget_entity))
      end
    end
  end

  # --- Conflict Rules ---------------------------------------------------------

  def conflict_for(row, destination_row:)
    reason_code = context_conflict_for(row)
    return conflict_details(row, reason_code) if reason_code

    owner = MasterRecordMerges::AllocationOwner.resolve(row).record
    owner_policy_conflict(row, owner, destination_row:)
  end

  def owner_policy_conflict(row, owner, destination_row:)
    return conflict_details(row, :subscription_owned_entity, subscription_id: owner.id) if owner.is_a?(Subscription)
    return budget_policy_conflict(row, owner) if owner.is_a?(Budget)
    return conflict_details(row, :unsupported_owner) unless owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction)

    transaction_policy_conflict(row, owner, destination_row:)
  end

  def transaction_policy_conflict(row, owner, destination_row:)
    structural_family = protected_structural_family(owner)
    return conflict_details(row, structural_reason(structural_family), family: structural_family) if structural_family

    source_reasons = AllocationMutations::EntityNeutrality.reasons(row)
    destination_reasons = destination_row.is_a?(EntityTransaction) ? AllocationMutations::EntityNeutrality.reasons(destination_row) : []
    if destination_reasons.any?
      return conflict_details(row, :same_transaction_conflict, destination_row_id: destination_row.id, source_reasons:, destination_reasons:)
    end
    return if source_reasons.empty?

    conflict_details(row, neutrality_reason(source_reasons), reasons: source_reasons)
  end

  def protected_structural_family(owner)
    AllocationMutations::StructuralFamily.call(owner).find do |family|
      family.in?(AllocationMutations::EntityPlanner::STRUCTURAL_FAMILIES) || family == :subscription_owned
    end
  end

  def structural_reason(family)
    return :subscription_owned_entity if family.in?(%i[subscription subscription_owned])
    return :piggy_bank_entity if family.in?(%i[piggy_bank piggy_bank_return])
    return :exchange_entity if family.in?(%i[exchange exchange_return borrow_return failed_return])

    :generated_family_entity
  end

  def neutrality_reason(reasons)
    return :payer_entity if reasons.include?(:payer)
    return :monetary_entity if reasons.intersect?(%i[price return])
    return :exchange_entity if reasons.include?(:exchanges)

    :entity_allocation_not_neutral
  end

  def budget_policy_conflict(row, budget)
    adapter = AllocationMutations::OwnerAdapter.for(budget)
    final_state = AllocationMutations::BudgetFinalState.new(
      budget:,
      category_ids: adapter.category_ids,
      entity_ids: (adapter.entity_ids - [ source_id ]) | [ destination_id ]
    )
    return if final_state.valid?

    conflict_details(row, :invalid_final_state, errors: final_state.errors)
  end

  def conflict_details(row, reason_code, details = {})
    {
      reason_code:,
      details: row_details(row, **details)
    }
  end

  def row_details(row, **details)
    identity = MasterRecordMerges::AllocationOwner.resolve(row)
    details.merge(graph_keys: graph_keys_for(identity.record))
  end

  def graph_keys_for(owner)
    graph_keys = Set.new
    append_graph_keys(graph_keys, owner)
    graph_keys.to_a.sort.freeze
  end

  def append_graph_keys(graph_keys, owner)
    return if owner.blank?

    owner_key = "#{owner.class.base_class.name}:#{owner.id}"
    return unless graph_keys.add?(owner_key)

    graph_keys << "Subscription:#{owner.subscription_id}" if owner.respond_to?(:subscription_id) && owner.subscription_id.present?
    append_graph_keys(graph_keys, owner.reference_transactable) if owner.respond_to?(:reference_transactable)
    append_graph_keys(graph_keys, owner.advance_cash_transaction) if owner.is_a?(CardTransaction) && owner.advance_cash_transaction_id.present?
  end

  def context_conflict_for(row)
    identity = MasterRecordMerges::AllocationOwner.resolve(row)
    return :unsupported_owner unless identity.supported?
    return :unowned_allocation unless identity.user_id == actor.id
    return :cross_context_allocation unless identity.context_id == context.id

    nil
  end

  def destination_transaction(entity_txn)
    EntityTransaction.find_by(
      entity: destination,
      transactable_type: entity_txn.transactable_type,
      transactable_id: entity_txn.transactable_id
    )
  end

  def destination_budget_entity(budget_entity)
    BudgetEntity.find_by(entity: destination, budget_id: budget_entity.budget_id)
  end

  def row_plan(row, status, reason_code = nil, details = {})
    EntityMerges::Plan::RowPlan.new(row:, status:, reason_code:, details:)
  end

  # --- Top-level Helpers ------------------------------------------------------

  def source
    @source ||= actor.entities.find_by(id: source_id)
  end

  def destination
    @destination ||= actor.entities.find_by(id: destination_id)
  end

  def conflict(reason_code)
    EntityMerges::Plan.new(
      actor:,
      context:,
      source: source || stub_entity(source_id),
      destination: destination || stub_entity(destination_id),
      mode:,
      outcome: :conflict,
      reason_code:
    )
  end

  def noop(reason_code)
    EntityMerges::Plan.new(
      actor:,
      context:,
      source: stub_entity(source_id),
      destination: stub_entity(destination_id),
      mode:,
      outcome: :noop,
      reason_code:
    )
  end

  def stub_entity(id)
    Entity.new.tap { |e| e.id = id }
  end
end
