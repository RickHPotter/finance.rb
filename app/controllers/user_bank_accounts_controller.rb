# frozen_string_literal: true

class UserBankAccountsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_user_bank_account, only: %i[show edit update destroy]
  before_action :set_banks, :set_user_bank_accounts, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    build_index_context
    @user_bank_accounts = user_bank_accounts_scope
    render Views::UserBankAccounts::Index.new(user_bank_accounts: @user_bank_accounts, index_context: @index_context, mobile: @mobile)
  end

  def new
    @user_bank_account = current_user.user_bank_accounts.new
    render Views::UserBankAccounts::New.new(current_user:, user_bank_account: @user_bank_account, banks: @banks)
  end

  def show
    render Views::UserBankAccounts::Show.new(user_bank_account: @user_bank_account)
  end

  def create
    @user_bank_account = Logic::UserBankAccounts.create(user_bank_account_params)

    handle_save
  end

  def edit
    render Views::UserBankAccounts::Edit.new(current_user:, user_bank_account: @user_bank_account, banks: @banks)
  end

  def update
    @user_bank_account = Logic::UserBankAccounts.update(@user_bank_account, user_bank_account_params)

    handle_save
  end

  def destroy
    @user_bank_account.destroy if @user_bank_account.cash_transactions.empty?

    respond_to(&:turbo_stream)
  end

  def handle_save
    if @user_bank_account.valid? && @user_bank_account.active?
      @cash_transaction = Logic::CashTransactions.create_from(user_bank_account: @user_bank_account)
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end

    respond_to(&:turbo_stream)
  end

  private

  def build_index_context
    @index_context = {
      search_term: search_params[:search_term],
      status: Array(filter_params[:status]).compact_blank
    }
  end

  def user_bank_accounts_scope
    build_index_context if @index_context.blank?

    scope = current_user.user_bank_accounts
    scope = scope.where(active: status_values) if @index_context[:status].present?

    if @index_context[:search_term].present?
      search_term = "%#{@index_context[:search_term].strip}%"
      scope = scope.where(
        "user_bank_account_name ILIKE :search OR agency_number ILIKE :search OR account_number ILIKE :search",
        search: search_term
      )
    end

    scope.order(active: :desc, user_bank_account_name: :asc)
  end

  def status_values
    @index_context[:status].filter_map do |status|
      case status
      when "active" then true
      when "inactive" then false
      end
    end.uniq
  end

  def set_basic_tabs
    set_tabs(active_menu: :data, active_sub_menu: :user_bank_account)
  end

  def set_user_bank_account
    @user_bank_account = current_user.user_bank_accounts.find(params[:id])
  end

  def user_bank_account_params
    params.require(:user_bank_account).permit(:user_bank_account_name, :account_number, :agency_number, :balance, :active, :bank_id, :user_id)
  end

  def search_params
    params.permit(:search_term)
  end

  def filter_params
    return {} if params[:user_bank_account].blank?

    params.require(:user_bank_account).permit(status: [])
  end
end
