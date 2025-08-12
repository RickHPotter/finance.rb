# frozen_string_literal: true

class UserBankAccountsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_user_bank_account, only: %i[edit update destroy]
  before_action :set_banks, :set_user_bank_accounts, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @user_bank_accounts = Logic::UserBankAccounts.find_by(current_user, conditions)

    respond_to do |format|
      format.html

      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :user_bank_account)
      end
    end
  end

  def new
    @user_bank_account = current_user.user_bank_accounts.new

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :user_bank_account) if params[:no_user_bank_account]
      end
    end
  end

  def create
    index
    @user_bank_account = Logic::UserBankAccounts.create(user_bank_account_params)

    if @user_bank_account.active?
      @cash_transaction = Logic::CashTransactions.create_from(user_bank_account: @user_bank_account) if @user_bank_account.valid?

      if @cash_transaction
        set_user_bank_accounts
        set_tabs(active_menu: :cash, active_sub_menu: :pix) if @user_bank_account.active?
      end
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    index
    @user_bank_account = Logic::UserBankAccounts.update(@user_bank_account, user_bank_account_params)

    if @user_bank_account.active?
      @cash_transaction = Logic::CashTransactions.create_from(user_bank_account: @user_bank_account) if @user_bank_account.valid?

      if @cash_transaction
        set_user_bank_accounts
        set_tabs(active_menu: :cash, active_sub_menu: :pix) if @user_bank_account.active?
      end
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @user_bank_account.destroy if @user_bank_account.cash_transactions.empty?
    set_tabs(active_menu: :basic, active_sub_menu: :user_bank_account)
    index

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user_bank_account
    @user_bank_account = current_user.user_bank_accounts.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_bank_account_params
    params.require(:user_bank_account).permit(:user_bank_account_name, :account_number, :agency_number, :balance, :active, :bank_id, :user_id)
  end
end
