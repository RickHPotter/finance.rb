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
    @index_context[:return_to] = user_bank_account_navigation_return_param(request.fullpath)
    render_top_level Views::UserBankAccounts::Index.new(user_bank_accounts: @user_bank_accounts, index_context: @index_context, mobile: @mobile)
  end

  def new
    @user_bank_account = current_user.user_bank_accounts.new
    set_return_to
    render_top_level Views::UserBankAccounts::New.new(current_user:, user_bank_account: @user_bank_account, banks: @banks, return_to: @return_to)
  end

  def show
    set_return_to
    render_top_level Views::UserBankAccounts::Show.new(user_bank_account: @user_bank_account, return_to: @return_to)
  end

  def create
    @user_bank_account = Logic::UserBankAccounts.create(user_bank_account_params)

    handle_save
  end

  def edit
    set_return_to
    render_top_level Views::UserBankAccounts::Edit.new(current_user:, user_bank_account: @user_bank_account, banks: @banks, return_to: @return_to)
  end

  def update
    @user_bank_account = Logic::UserBankAccounts.update(@user_bank_account, user_bank_account_params)

    handle_save
  end

  def destroy
    set_return_to
    @user_bank_account.destroy if @user_bank_account.cash_transactions.empty?

    if @user_bank_account.destroyed?
      redirect_to @return_to, notice: notification_model(:destroyeda, UserBankAccount), status: :see_other
    else
      redirect_to @return_to, alert: user_bank_account_destroy_failure_notification, status: :see_other
    end
  end

  def handle_save
    set_return_to
    return render_user_bank_account_failure unless @user_bank_account.valid?

    if @user_bank_account.active?
      @cash_transaction = Logic::CashTransactions.create_from(user_bank_account: @user_bank_account)
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end

    redirect_to user_bank_account_save_destination,
                notice: notification_model(action_name == "create" ? :createda : :updateda, UserBankAccount),
                status: :see_other
  end

  private

  def render_top_level(view)
    respond_to { |format| format.html { render view } }
  end

  def render_user_bank_account_failure
    view =
      if action_name == "create"
        Views::UserBankAccounts::New.new(current_user:, user_bank_account: @user_bank_account, banks: @banks, return_to: @return_to)
      else
        Views::UserBankAccounts::Edit.new(current_user:, user_bank_account: @user_bank_account, banks: @banks, return_to: @return_to)
      end

    respond_to do |format|
      format.html { render view, status: :unprocessable_content }
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def user_bank_account_save_destination
    return @return_to if @cash_transaction.blank?

    new_cash_transaction_path(user_bank_account_id: @user_bank_account.id)
  end

  def set_return_to
    @return_to = dashboard_navigation_destination(params[:return_to]) || user_bank_account_navigation_destination(params[:return_to])
  end

  def user_bank_account_navigation_destination(raw)
    Navigation::UserBankAccounts.new(raw:, fallback: user_bank_accounts_path, current_user:).destination
  end

  def user_bank_account_navigation_return_param(raw)
    destination = user_bank_account_navigation_destination(raw)
    destination unless destination == user_bank_accounts_path
  end

  def user_bank_account_destroy_failure_notification
    @user_bank_account.errors.full_messages.to_sentence.presence ||
      notification_model(:not_destroyed_because_has_transactionsa, UserBankAccount)
  end

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
        "user_bank_account_name ILIKE :search OR agency_number::text ILIKE :search OR account_number::text ILIKE :search",
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
