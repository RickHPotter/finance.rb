# frozen_string_literal: true

class AllocationMutationPreviewsController < ApplicationController
  include TabsConcern

  before_action :set_allocation_tabs

  def create
    preview = AllocationMutations::BatchPlanner.new(
      actor: current_user,
      context: current_context,
      owner_type: allocation_params.fetch(:owner_type),
      owner_ids:,
      selected_row_count: allocation_params[:selected_row_count],
      action: allocation_action
    ).call

    respond_to do |format|
      format.html { render Views::AllocationMutationPreviews::Show.new(preview:, return_to: allocation_params[:return_to]) }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "allocation_mutation_preview",
          Views::AllocationMutationPreviews::Show.new(preview:, return_to: allocation_params[:return_to], frame_only: true)
        )
      end
      format.json { render json: preview.to_h }
    end
  rescue ActionController::ParameterMissing, ArgumentError
    head :bad_request
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def allocation_params
    @allocation_params ||= params.require(:allocation_mutation).permit(
      :owner_type,
      :selected_row_count,
      :return_to,
      owner_ids: [],
      action: %i[allocation_type operation source_id destination_id]
    )
  end

  def allocation_action
    AllocationMutations::Action.new(**allocation_params.require(:action).to_h.symbolize_keys)
  end

  def owner_ids
    raw_ids = allocation_params[:owner_ids].presence || params.dig(:allocation_mutation, :owner_ids)
    Array(raw_ids).flat_map { |value| value.to_s.split(",") }
  end

  def set_allocation_tabs
    case params.dig(:allocation_mutation, :owner_type)
    when "CardTransaction"
      set_tabs(active_menu: :card, active_sub_menu: :search)
    when "Budget"
      set_tabs(active_menu: :cash, active_sub_menu: :budget)
    else
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end
  end
end
