# frozen_string_literal: true

class Reports::UserCardMovementsController < ApplicationController
  def show
    user_card = current_user.user_cards.find(params[:user_card_id])
    query_state = Reports::QueryState.new(report_params)
    render json: Reports::UserCardMovement.new(context: current_context, user_card:, query_state:).call
  rescue Reports::QueryState::InvalidState => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_content
  end

  private

  def report_params
    params.permit(:from_date, :to_date, :granularity, :paid_state, :direction, :sort)
  end
end
