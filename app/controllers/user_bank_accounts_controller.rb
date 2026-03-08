# frozen_string_literal: true

class UserBankAccountsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_user_bank_account, only: %i[edit update destroy]
  before_action :set_banks, :set_user_bank_accounts, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @user_bank_accounts = Logic::UserBankAccounts.find_by(current_user, conditions)
    render Views::UserBankAccounts::Index.new(user_bank_accounts: @user_bank_accounts, mobile: @mobile)
  end

  def new
    @user_bank_account = current_user.user_bank_accounts.new
    render Views::UserBankAccounts::New.new(current_user:, user_bank_account: @user_bank_account, banks: @banks)
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

  def set_basic_tabs
    set_tabs(active_menu: :basic, active_sub_menu: :user_bank_account)
  end

  def set_user_bank_account
    @user_bank_account = current_user.user_bank_accounts.find(params[:id])
  end

  def user_bank_account_params
    params.require(:user_bank_account).permit(:user_bank_account_name, :account_number, :agency_number, :balance, :active, :bank_id, :user_id)
  end
end
