# frozen_string_literal: true

class Reports::BudgetPerformancesController < ApplicationController
  def show
    budget = current_context.budgets.find(params[:budget_id])
    render json: Reports::BudgetPerformance.new(budget:).call
  end
end
