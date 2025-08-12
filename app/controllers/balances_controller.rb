# frozen_string_literal: true

# Controller for Balances Chart
class BalancesController < ApplicationController
  include TabsConcern

  before_action :set_tabs, only: :index

  def index
    render Views::Balances::Index.new(mobile: @mobile)
  end

  def json
    result = Logic::MonthlyBalanceBuilder.new(user: current_user).call
    render json: result
  end
end
