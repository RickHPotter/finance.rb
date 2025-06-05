# frozen_string_literal: true

class CashTransactionsController < ApplicationController
  include TabsConcern

  before_action :set_tabs
  before_action :set_cash_transaction, only: %i[edit update destroy]

  def index
    build_index_context(current_user.cash_installments)

    respond_to do |format|
      format.html do
        render Views::CashTransactions::Index.new(index_context: @index_context)
      end

      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end
    end
  end

  def month_year
    mobile = search_cash_transaction_params[:force_mobile] || @mobile
    month_year = search_cash_transaction_params[:month_year]
    month_year_str = I18n.l(Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01"), format: "%B %Y")

    cash_installments, budgets = Logic::CashTransactions.find_by_ref_month_year(current_user, cash_transaction_params, search_cash_transaction_params)

    render Views::CashTransactions::MonthYear.new(mobile:, month_year:, month_year_str:, cash_installments:, budgets:)
  end

  def show; end

  def new
    @cash_transaction = current_user.cash_transactions.new(
      user_bank_account_id: params[:user_bank_account_id] || current_user.user_bank_accounts.active.first&.id,
      date: Time.zone.now
    )
    @cash_transaction.build_month_year

    respond_to do |format|
      format.html { render Views::CashTransactions::New.new(current_user:, cash_transaction: @cash_transaction) }
      format.turbo_stream
    end
  end

  def edit
    @cash_transaction = current_user.cash_transactions.includes(:cash_installments).find(params[:id])

    respond_to do |format|
      format.html { render Views::CashTransactions::New.new(current_user:, cash_transaction: @cash_transaction) }
      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end
    end
  end

  def create
    @cash_transaction = current_user.cash_transactions.new(cash_transaction_params.merge(imported: false))
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id

    handle_save
  end

  def update
    @cash_transaction.assign_attributes(cash_transaction_params.merge(imported: false))
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id

    handle_save
  end

  def destroy
    @user_bank_account = @cash_transaction.user_bank_account
    @cash_transaction.destroy
    index

    respond_to(&:turbo_stream)
  end

  def handle_save # rubocop:disable Metrics/AbcSize
    if params[:commit] == "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            @cash_transaction,
            Views::CashTransactions::Form.new(current_user: @current_user, cash_transaction: @cash_transaction)
          )
        end
      end
    else
      if @cash_transaction.save
        index
        @index_context[:user_bank_account_id] = @cash_transaction.user_bank_account_id
        @index_context[:default_year] = @cash_transaction.cash_installments.first.year
        @index_context[:active_month_years] = @cash_transaction.cash_installments.map { |i| Date.new(i.year, i.month).strftime("%Y%m").to_i }.uniq
        @index_context[:search_term] = @cash_transaction.description

        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end

      respond_to(&:turbo_stream)
    end
  end

  def build_index_context(cash_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    min_date = cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    max_date = cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    default_active_month_years = [ Time.zone.today.clamp(min_date, max_date).strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)

    category_id = [ cash_transaction_params[:category_id] ].flatten&.compact_blank
    entity_id = [ cash_transaction_params[:entity_id] ].flatten&.compact_blank
    user_bank_account_id = [ cash_transaction_params[:user_bank_account_id] ].flatten&.compact_blank
    search_term = search_cash_transaction_params[:search_term]
    from_ct_price = search_cash_transaction_params[:from_ct_price]
    to_ct_price = search_cash_transaction_params[:to_ct_price]
    from_price = search_cash_transaction_params[:from_price]
    to_price = search_cash_transaction_params[:to_price]
    from_installments_count = search_cash_transaction_params[:from_installments_count]
    to_installments_count = search_cash_transaction_params[:to_installments_count]
    paid = ActiveModel::Type::Boolean.new.cast(search_cash_transaction_params[:paid])
    pending = ActiveModel::Type::Boolean.new.cast(search_cash_transaction_params[:pending])
    skip_budgets = search_cash_transaction_params[:skip_budgets]
    force_mobile = search_cash_transaction_params[:force_mobile]

    if params[:all_month_years]
      associations = {}
      associations.merge!(categories: { id: category_id }) if category_id.present?
      associations.merge!(entities: { id: entity_id })     if entity_id.present?

      cash_transaction_conditions = { user_bank_account_id: }.compact_blank

      cash_installments
        .joins(cash_transaction: associations.keys)
        .where(cash_transaction: associations.merge(cash_transaction_conditions))
        .map { |i| Date.new(i.year, i.month).strftime("%Y%m").to_i }
        .uniq
    else
      params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
    end => active_month_years
    default_year = (active_month_years.max.to_s.first(4) || params[:default_year])&.to_i || [ max_date, Time.zone.today ].min.year

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      category_id:,
      entity_id:,
      user_bank_account_id:,
      from_ct_price:,
      to_ct_price:,
      from_price:,
      to_price:,
      from_installments_count:,
      to_installments_count:,
      user_card: @user_card,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:
    }
  end

  def inspect
    @cash_installments = Logic::CashInstallments.find_by_query(current_user, params[:entity_id], params[:query])

    render json: @cash_installments.map { |ci|
      {
        id: ci.id,
        date: I18n.l(ci.date.to_date, format: :shorter),
        price: from_cent_based_to_float(ci.price, "R$"),
        description: ci.cash_transaction.description,
        cash_installments_count: ci.cash_installments_count,
        pretty_installments: pretty_installments(ci.number, ci.cash_installments_count),
        bg_colour: ci.cash_transaction.categories&.first&.bg_colour,
        categories: ci.cash_transaction.categories.map(&:category_name)
      }
    }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_cash_transaction
    @cash_transaction = current_user.cash_transactions.find(params[:id])
  end

  def search_cash_transaction_params
    params.permit(
      %i[
        search_term
        from_ct_price
        to_ct_price
        from_price
        to_price
        from_installments_count
        to_installments_count
        paid
        pending
        month_year
        skip_budgets
        force_mobile
      ]
    )
  end

  # Only allow a list of trusted parameters through.
  def cash_transaction_params
    return {} if params[:cash_transaction].blank?

    params.require(:cash_transaction).permit(
      %i[id description comment date month year price paid user_id user_bank_account_id category_id entity_id],
      user_bank_account_id: [], category_id: [], entity_id: [],
      category_transactions_attributes: %i[id category_id _destroy],
      cash_installments_attributes: %i[id number date month year price _destroy],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price, :price_to_be_returned, :_destroy,
        { exchanges_attributes: %i[id number exchange_type bound_type price _destroy] }
      ]
    )
  end
end
