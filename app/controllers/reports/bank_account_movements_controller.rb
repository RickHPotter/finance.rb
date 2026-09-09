# frozen_string_literal: true

class Reports::BankAccountMovementsController < ApplicationController
  def show
    user_bank_account = current_user.user_bank_accounts.find(params[:user_bank_account_id])
    query_state = Reports::QueryState.new(report_params)
    render json: Reports::BankAccountMovement.new(context: current_context, user_bank_account:, query_state:).call
  rescue Reports::QueryState::InvalidState => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_content
  end

  private

  def report_params
    params.permit(:from_date, :to_date, :granularity, :paid_state, :direction, :sort)
  end
end
