# frozen_string_literal: true

class AllocationMutations::Preview
  REPRESENTATIVE_LIMIT = 5

  attr_reader :actor, :context, :selection, :action, :plans, :digest, :apply_token

  delegate :owner_type, :owner_ids, :selected_row_count, to: :selection

  def initialize(actor:, context:, selection:, action:, plans:)
    @actor = actor
    @context = context
    @selection = selection
    @action = action
    @plans = Array(plans).sort_by { |plan| plan.owner.id }.freeze

    validate!
    @digest = Digest::SHA256.hexdigest(AllocationMutations::Payload.canonical_json(digest_payload)).freeze
    @apply_token = AllocationMutations::PreviewToken.generate(token_payload).freeze
    freeze
  end

  def unique_owner_count = plans.size
  def eligible_count = plans.count(&:eligible?)
  def affected_count = eligible_count
  def noop_count = plans.count(&:noop?)
  def conflict_count = plans.count(&:conflict?)
  def strict_apply_available? = eligible_count.positive? && conflict_count.zero?

  def eligible_only_available?
    AllocationMutations::IndependenceClassifier.new(plans:).eligible_only_available?
  end

  def reason_groups
    groups = plans.group_by { |plan| [ plan.outcome.status, plan.outcome.reason_code ] }.map do |(status, reason_code), grouped_plans|
      {
        status:,
        reason_code:,
        label: I18n.t(
          "allocation_mutations.reasons.#{reason_code}",
          default: reason_code.to_s.humanize
        ),
        count: grouped_plans.size,
        owners: grouped_plans.first(REPRESENTATIVE_LIMIT).map { |plan| owner_reference(plan.owner) }
      }.freeze
    end
    groups.sort_by { |group| [ group[:status].to_s, group[:reason_code].to_s ] }.freeze
  end

  def to_h
    {
      action: action.to_h,
      source_label: allocation_label(action.source_id),
      destination_label: allocation_label(action.destination_id),
      selected_row_count:,
      unique_owner_count:,
      eligible_count:,
      affected_count:,
      noop_count:,
      conflict_count:,
      strict_apply_available: strict_apply_available?,
      eligible_only_available: eligible_only_available?,
      reasons: reason_groups,
      digest:,
      apply_token:
    }.freeze
  end

  def digest_payload
    {
      selection: selection.to_h,
      action: action.to_h,
      plans: plans.map { |plan| plan_fingerprint(plan) }
    }.freeze
  end

  def token_payload
    {
      "actor_id" => actor.id,
      "context_id" => context.id,
      "selection" => selection.to_h,
      "action" => action.to_h,
      "digest" => digest
    }.freeze
  end

  private

  def validate!
    raise ArgumentError, "preview actor does not match selection" unless actor == selection.actor
    raise ArgumentError, "preview context does not match selection" unless context == selection.context
    raise ArgumentError, "allocation action required" unless action.is_a?(AllocationMutations::Action)
    raise ArgumentError, "preview plans do not match selection" unless plans.map { |plan| plan.owner.id } == owner_ids
    raise ArgumentError, "preview plan actions do not match" unless plans.all? { |plan| plan.action == action }
  end

  def plan_fingerprint(plan)
    state =
      if plan.is_a?(AllocationMutations::CategoryPlan)
        { category_ids_before: plan.category_ids_before, category_ids_after: plan.category_ids_after }
      else
        { entity_ids_before: plan.entity_ids_before, entity_ids_after: plan.entity_ids_after }
      end

    {
      owner_type: plan.outcome.owner_type,
      owner_id: plan.outcome.owner_id,
      status: plan.outcome.status,
      reason_code: plan.outcome.reason_code,
      details: plan.outcome.details.except(:errors),
      state:
    }
  end

  def allocation_label(allocation_id)
    return if allocation_id.blank?

    allocation_scope.find_by(id: allocation_id)&.name
  end

  def allocation_scope
    action.allocation_type == :category ? actor.categories : actor.entities
  end

  def owner_reference(owner)
    {
      owner_type: owner.class.base_class.name,
      owner_id: owner.id,
      label: owner.respond_to?(:description) ? owner.description : "#{owner.class.model_name.human} ##{owner.id}",
      path: Rails.application.routes.url_helpers.polymorphic_path(owner)
    }.freeze
  end
end
