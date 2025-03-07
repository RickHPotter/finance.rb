# frozen_string_literal: true

# Controller for CashTransaction
class CashTransactionsController < ApplicationController
  include TabsConcern
  include ApplicationHelper

  before_action :set_tabs
  before_action :set_cash_transaction, only: %i[edit update destroy]
  before_action :set_banks, :set_user_bank_accounts, :set_entities, :set_categories, only: %i[new create edit update]

  def inspect
    entity_id = params[:entity_id]

    @cash_installments =
      current_user
      .cash_installments
      .includes(cash_transaction: %i[category_transactions entity_transactions])
      .where(cash_transaction: { entity_transactions: { entity_id: } })
      .where("cash_transaction.description ILIKE '%#{params[:query]}%'")

    render json: @cash_installments.map { |ci|
      {
        id: ci.id,
        date: I18n.l(ci.date.to_date, format: :shorter),
        price: from_cent_based_to_float(ci.price, "R$"),
        description: ci.cash_transaction.description.to_s,
        cash_installments_count: ci.cash_installments_count,
        pretty_installments: pretty_installments(ci.number, ci.cash_installments_count),
        bg_colour: ci.cash_transaction.categories&.first&.bg_colour,
        categories: ci.cash_transaction.categories.map(&:category_name)
      }
    }
  end

  def index
    index_variables(current_user.cash_installments)
    search_variables

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end
    end
  end

  def index_variables(cash_installments)
    min_date = cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    max_date = cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    default_active_month_years = [ [ max_date, Date.current ].min.strftime("%Y%m").to_i ]
    @years = (min_date.year..max_date.year)
    @default_year = params[:default_year]&.to_i || [ max_date, Date.current ].min.year
    @active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
    set_all_categories
    set_entities
  end

  def search_variables
    @search_term = search_cash_transaction_params[:search_term]
    @category_ids = search_cash_transaction_params[:category_ids] || [ params[:category_id] ].compact_blank
    @entity_ids = search_cash_transaction_params[:entity_ids]     || [ params[:entity_id]   ].compact_blank
    @from_ct_price = search_cash_transaction_params[:from_ct_price]
    @to_ct_price = search_cash_transaction_params[:to_ct_price]
    @from_price = search_cash_transaction_params[:from_price]
    @to_price = search_cash_transaction_params[:to_price]
    @from_installments_count = search_cash_transaction_params[:from_installments_count]
    @to_installments_count = search_cash_transaction_params[:to_installments_count]
  end

  def month_year
    @month_year = params[:month_year]
    @month_year_str = I18n.l(Date.parse("#{@month_year[0..3]}-#{@month_year[4..]}-01"), format: "%B %Y")
    @user_bank_account_id = params[:user_bank_account_id]

    @cash_installments, @budgets = Logic::CashTransactions.find_by_ref_month_year(current_user, params.to_unsafe_h)
  end

  def show; end

  def new
    @cash_transaction = CashTransaction.new(user_bank_account_id: params[:user_bank_account_id] || current_user.user_bank_accounts.active.first&.id)
    @cash_transaction.build_month_year

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def edit
    @cash_transaction = CashTransaction.includes(:cash_installments).find(params[:id])
  end

  def create
    @cash_transaction = CashTransaction.new(cash_transaction_params)
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id

    if params[:commit] == "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@cash_transaction, partial: "cash_transactions/form", locals: { cash_transaction: @cash_transaction })
        end
      end
    else
      if @cash_transaction.save
        @user_bank_account = @cash_transaction.user_bank_account
        index
        load_index_based_on_save
        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end

      respond_to(&:turbo_stream)
    end
  end

  def update
    @cash_transaction.assign_attributes(cash_transaction_params)
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id

    if params[:commit] == "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@cash_transaction, partial: "cash_transactions/form", locals: { cash_transaction: @cash_transaction })
        end
      end
    else
      if @cash_transaction.save
        @user_bank_account = @cash_transaction.user_bank_account
        index
        load_index_based_on_save
        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end

      respond_to(&:turbo_stream)
    end
  end

  def destroy
    @user_bank_account = @cash_transaction.user_bank_account
    @cash_transaction.destroy
    index

    respond_to(&:turbo_stream)
  end

  def pay_cash_installment
    @cash_installment = current_user.cash_installments.find(params[:id])
    @cash_installment.update(date: DateTime.current, paid: true)
    @cash_installment.balance = params[:balance]

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(@cash_installment, partial: "cash_installments/cash_installment", locals: { cash_installment: @cash_installment }),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: notification_model(:updateda, CashInstallment) })
        ]
      end
    end
  end

  def load_index_based_on_save
    @default_year = @cash_transaction.cash_installments.first.year
    @active_month_years = @cash_transaction.cash_installments.map do |cash_installment|
      Date.new(cash_installment.year, cash_installment.month, 1).strftime("%Y%m").to_i
    end
    @search_term = @cash_transaction.description
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_cash_transaction
    @cash_transaction = CashTransaction.find(params[:id])
  end

  def search_cash_transaction_params
    return {} if params[:cash_transaction].blank?

    params.require(:cash_transaction).permit(
      %i[search_term from_ct_price to_ct_price from_price to_price from_installments_count to_installments_count], category_ids: [], entity_ids: []
    )
  end

  # Only allow a list of trusted parameters through.
  def cash_transaction_params
    params.require(:cash_transaction).permit(
      %i[id description comment date month year price paid user_id user_bank_account_id],
      category_transactions_attributes: %i[id category_id],
      cash_installments_attributes: %i[id number date month year price],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price,
        { exchanges_attributes: %i[id exchange_type price] }
      ]
    )
  end
end
