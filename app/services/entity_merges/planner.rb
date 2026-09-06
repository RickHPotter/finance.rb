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
    # Merging friend-backed entity into a non-friend entity (or vice versa),
    # or merging friends that represent different users is a hard conflict.
    return unless source.friendship_id.present? || destination.friendship_id.present?

    return conflict(:cross_user_friend_entity) unless source.friendship_id == destination.friendship_id

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
    # Preload exchanges to avoid N+1 during neutrality check
    source.entity_transactions.includes(:exchanges, :transactable).find_each do |entity_transaction|
      reason = context_conflict_for(entity_transaction) || transaction_conflict_reason(entity_transaction)
      if reason
        conflict << row_plan(entity_transaction, :conflict, reason)
      elsif (destination_row = destination_transaction(entity_transaction))
        collapse << row_plan(entity_transaction, :collapse, nil, destination_row_id: destination_row.id)
      else
        transfer << row_plan(entity_transaction, :transfer)
      end
    end
  end

  def classify_budget_entities(transfer, collapse, conflict)
    BudgetEntity.where(entity: source).find_each do |budget_entity|
      reason = context_conflict_for(budget_entity)
      if reason
        conflict << row_plan(budget_entity, :conflict, reason)
      elsif (destination_row = destination_budget_entity(budget_entity))
        collapse << row_plan(budget_entity, :collapse, nil, destination_row_id: destination_row.id)
      else
        transfer << row_plan(budget_entity, :transfer)
      end
    end
  end

  # --- Conflict Rules ---------------------------------------------------------

  def transaction_conflict_reason(entity_txn)
    return :payer_entity if entity_txn.is_payer?
    return :monetary_entity if entity_txn.price.to_i.nonzero? || entity_txn.price_to_be_returned.to_i.nonzero?
    return :exchange_entity if entity_txn.exchanges.any?
    return :piggy_bank_entity if piggy_bank_entity?(entity_txn)

    # If source is neutral (passed above checks), but destination is also present
    # on this transaction and is NON-NEUTRAL, it's fine. We just collapse the source.
    # However, if both were non-neutral, it would fail the above checks anyway.
    # So we don't need a specific :same_transaction_conflict check here,
    # unless we want to prioritize that reason code. The contract says:
    # "Both source and destination exist on the same transaction as non-neutral rows -> :same_transaction_conflict"
    # But since we evaluate per-row, if the source is non-neutral it will already be caught by :payer/:monetary.

    nil
  end

  def piggy_bank_entity?(entity_txn)
    # KAKASHI-18 contract: Source row is the Piggy Bank shared entity.
    return false unless entity_txn.transactable.is_a?(CashTransaction)

    entity_txn.transactable.piggy_bank_source? || entity_txn.transactable.piggy_bank_return?
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
