# frozen_string_literal: true

class Reports::CategoryTrendsController < ApplicationController
  def show
    category = current_user.categories.find(params[:category_id])
    query_state = Reports::QueryState.new(report_params)
    render json: Reports::CategoryTrend.new(context: current_context, category:, query_state:).call
  rescue Reports::QueryState::InvalidState => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_content
  end

  private

  def report_params
    params.permit(:from_date, :to_date, :granularity, :paid_state, :direction, :sort)
  end
end
