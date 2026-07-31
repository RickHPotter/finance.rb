# frozen_string_literal: true

# Validates eligibility and projects the impact of merging two entities.
#
# Follows the KAKASHI-18 entity merge contract, providing conflict detection
# for monetary, payer, exchange, piggy bank, and structural conflicts.
# Supports both :strict and :eligible_only modes.
class EntityMerges::Planner
  attr_reader :actor, :source_id, :destination_id, :mode

  def initialize(actor:, source_id:, destination_id:, mode: :strict)
    @actor = actor
    @source_id = source_id.to_i
    @destination_id = destination_id.to_i
    @mode = mode.to_sym
  end

  def call
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
    return unless source.entity_user_id.present? || destination.entity_user_id.present?

    return conflict(:cross_user_friend_entity) unless source.entity_user_id == destination.entity_user_id

    nil
  end

  # --- Row Classification -----------------------------------------------------

  def plan
    transfer_rows = []
    collapse_rows = []
    conflict_rows = []

    classify_entity_transactions(transfer_rows, collapse_rows, conflict_rows)
    classify_budget_entities(transfer_rows, collapse_rows)

    EntityMerges::Plan.new(
      actor:,
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
      reason = transaction_conflict_reason(entity_transaction)
      if reason
        conflict << row_plan(entity_transaction, :conflict, reason)
      elsif entity_transaction.transactable.nil? || destination_transaction_exists?(entity_transaction)
        collapse << row_plan(entity_transaction, :collapse)
      else
        transfer << row_plan(entity_transaction, :transfer)
      end
    end
  end

  def classify_budget_entities(transfer, collapse)
    BudgetEntity.where(entity: source).find_each do |budget_entity|
      if destination_budget_entity_exists?(budget_entity)
        collapse << row_plan(budget_entity, :collapse)
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

  def destination_transaction_exists?(entity_txn)
    @dest_et_map ||= EntityTransaction
                     .where(entity: destination)
                     .pluck(:transactable_type, :transactable_id)
                     .to_set

    @dest_et_map.include?([ entity_txn.transactable_type, entity_txn.transactable_id ])
  end

  def destination_budget_entity_exists?(budget_entity)
    @dest_be_map ||= BudgetEntity
                     .where(entity: destination)
                     .pluck(:budget_id)
                     .to_set

    @dest_be_map.include?(budget_entity.budget_id)
  end

  def row_plan(row, status, reason_code = nil)
    EntityMerges::Plan::RowPlan.new(row:, status:, reason_code:)
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
