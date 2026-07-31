# frozen_string_literal: true

class EntityMergePreviewsController < ApplicationController
  include TabsConcern

  before_action :set_source_entity
  before_action :set_basic_tabs

  def create
    @destinations = load_destinations
    plan = build_plan

    respond_to do |format|
      format.html { render Views::EntityMerges::Preview.new(source: @source, plan:, destinations: @destinations, return_to: return_to_path) }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "entity_merge_preview_#{@source.id}",
          Views::EntityMerges::Preview.new(source: @source, plan:, destinations: @destinations, return_to: return_to_path, frame_only: true)
        )
      end
      format.json { render json: plan_payload(plan) }
    end
  rescue ActionController::ParameterMissing, ArgumentError
    head :bad_request
  end

  private

  def load_destinations
    current_user.entities
                .where(active: true, built_in: false)
                .where.not(id: @source.id)
                .order(:entity_name)
  end

  def build_plan
    mode = (merge_params[:mode].presence || "strict").to_sym
    EntityMerges::Planner.new(
      actor: current_user,
      source_id: @source.id,
      destination_id: merge_params[:destination_id],
      mode:
    ).call
  end

  def set_source_entity
    @source = current_user.entities.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def merge_params
    params.require(:entity_merge).permit(:destination_id, :return_to, :mode)
  end

  def return_to_path
    merge_params[:return_to].presence || entities_path
  end

  def plan_payload(plan)
    {
      outcome: plan.outcome,
      transaction_reassign_count: plan.transaction_reassign_count,
      transaction_dedup_count: plan.transaction_dedup_count,
      budget_reassign_count: plan.budget_reassign_count,
      budget_dedup_count: plan.budget_dedup_count
    }
  end

  def set_basic_tabs
    set_tabs(active_menu: :data, active_sub_menu: :entity)
  end
end
