# frozen_string_literal: true

class Reports::EntityTrendsController < ApplicationController
  def show
    entity = current_user.entities.find(params[:entity_id])
    query_state = Reports::QueryState.new(report_params)
    render json: Reports::EntityTrend.new(context: current_context, entity:, query_state:).call
  rescue Reports::QueryState::InvalidState => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_content
  end

  private

  def report_params
    params.permit(:from_date, :to_date, :granularity, :paid_state, :direction, :sort)
  end
end
