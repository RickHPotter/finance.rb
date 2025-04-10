# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  include TabsConcern

  before_action :set_tabs
  before_action :set_card_transaction, only: %i[edit update destroy]
  before_action :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @user_card ||= current_user.user_cards.find_by(id: params[:user_card_id])                  if params[:user_card_id]
    @user_card ||= current_user.user_cards.find_by(id: card_transaction_params[:user_card_id]) if params[:card_transaction]
    @user_card_id = @user_card&.id

    build_context(@user_card.card_installments)

    respond_to do |format|
      format.html do
        render Views::CardTransactions::Index.new(index_context: @index_context)
      end

      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name || :search)
      end
    end
  end

  def search
    build_context(current_user.card_installments)

    respond_to do |format|
      format.html do
        render Views::CardTransactions::Index.new(index_context: @index_context, search: true)
      end

      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: :search)
      end
    end
  end

  def build_context(card_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    default_active_month_years = [ [ max_date, Date.current ].min.strftime("%Y%m").to_i ]
    @years = (min_date.year..max_date.year)
    @default_year = params[:default_year]&.to_i || [ max_date, Date.current ].min.year
    @active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
    set_all_categories
    set_entities

    @search_term = search_card_transaction_params[:search_term]
    @category_ids = search_card_transaction_params[:category_ids] || [ params[:category_id] ].compact_blank
    @entity_ids = search_card_transaction_params[:entity_ids]     || [ params[:entity_id]   ].compact_blank
    @from_ct_price = search_card_transaction_params[:from_ct_price]
    @to_ct_price = search_card_transaction_params[:to_ct_price]
    @from_price = search_card_transaction_params[:from_price]
    @to_price = search_card_transaction_params[:to_price]
    @from_installments_count = search_card_transaction_params[:from_installments_count]
    @to_installments_count = search_card_transaction_params[:to_installments_count]

    @index_context = {
      current_user:,
      default_year: @default_year,
      years: @years,
      active_month_years: @active_month_years,
      search_term: @search_term,
      category_ids: @category_ids,
      entity_ids: @entity_ids,
      from_ct_price: @from_ct_price,
      to_ct_price: @to_ct_price,
      from_price: @from_price,
      to_price: @to_price,
      from_installments_count: @from_installments_count,
      to_installments_count: @to_installments_count,
      user_card: @user_card,
      user_card_id: @user_card&.id,
      categories: @categories,
      entities: @entities
    }
  end

  def index_variables(card_installments)
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Date.current
    default_active_month_years = [ [ max_date, Date.current ].min.strftime("%Y%m").to_i ]
    @years = (min_date.year..max_date.year)
    @default_year = params[:default_year]&.to_i || [ max_date, Date.current ].min.year
    @active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
    set_all_categories
    set_entities
  end

  def search_variables
    @search_term = search_card_transaction_params[:search_term]
    @category_ids = search_card_transaction_params[:category_ids] || [ params[:category_id] ].compact_blank
    @entity_ids = search_card_transaction_params[:entity_ids]     || [ params[:entity_id]   ].compact_blank
    @from_ct_price = search_card_transaction_params[:from_ct_price]
    @to_ct_price = search_card_transaction_params[:to_ct_price]
    @from_price = search_card_transaction_params[:from_price]
    @to_price = search_card_transaction_params[:to_price]
    @from_installments_count = search_card_transaction_params[:from_installments_count]
    @to_installments_count = search_card_transaction_params[:to_installments_count]
  end

  def month_year
    @month_year = params[:month_year]
    @month_year_str = I18n.l(Date.parse("#{@month_year[0..3]}-#{@month_year[4..]}-01"), format: "%B %Y")
    @user_card_id = params[:user_card_id]

    @card_installments = Logic::CardInstallments.find_ref_month_year_by_params(current_user, params.to_unsafe_h)
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new(user_card_id: params[:user_card_id] || current_user.user_cards.active.order(:user_card_name).first.id,
                                            date: DateTime.current)
    @card_transaction.build_month_year

    respond_to do |format|
      format.html { render Views::CardTransactions::New.new(current_user:, card_transaction: @card_transaction) }
      format.turbo_stream
    end
  end

  def edit
    @card_transaction = CardTransaction.includes(:card_installments).find(params[:id])

    render Views::CardTransactions::New.new(current_user:, card_transaction: @card_transaction)
  end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)
    @card_transaction.build_month_year if @card_transaction.user_card_id

    handle_save
  end

  def update
    @card_transaction.assign_attributes(card_transaction_params)
    @card_transaction.build_month_year if @card_transaction.user_card_id

    handle_save
  end

  def handle_save
    if params[:commit] == "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            @card_transaction,
            Views::CardTransactions::Form.new(current_user: @current_user, card_transaction: @card_transaction)
          )
        end
      end
    else
      if @card_transaction.save
        index
        @user_card = @card_transaction.user_card
        @default_year = @card_transaction.year
        @active_month_years = @card_transaction.card_installments.map { |i| Date.new(i.year, i.month).strftime("%Y%m").to_i }
        @search_term = @card_transaction.description
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end

      respond_to(&:turbo_stream)
    end
  end

  def destroy
    @user_card = @card_transaction.user_card
    @card_transaction.destroy
    index

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @card_transaction = CardTransaction.find(params[:id])
  end

  def search_card_transaction_params
    return {} if params[:card_transaction].blank?

    params.require(:card_transaction).permit(
      %i[search_term from_ct_price to_ct_price from_price to_price from_installments_count to_installments_count], category_ids: [], entity_ids: []
    )
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      %i[id description comment date month year price paid user_id user_card_id],
      category_transactions_attributes: %i[id category_id _destroy],
      card_installments_attributes: %i[id number date month year price _destroy],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price, :_destroy,
        { exchanges_attributes: %i[id number exchange_type price _destroy] }
      ]
    )
  end
end
