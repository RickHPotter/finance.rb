# frozen_string_literal: true

class CardTransactionsController < ApplicationController
  include TabsConcern

  before_action :set_tabs
  before_action :set_card_transaction, only: %i[edit update destroy]

  def index
    @user_card = current_user.user_cards.find_by(id: params[:user_card_id]) if params[:user_card_id]
    @user_card ||= current_user.user_cards.find_by(id: card_transaction_params[:user_card_id])

    build_index_context(@user_card.card_installments)

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
    build_index_context(current_user.card_installments)

    respond_to do |format|
      format.html do
        render Views::CardTransactions::Index.new(index_context: @index_context, search: true)
      end

      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: :search)
      end
    end
  end

  def month_year
    mobile = search_card_transaction_params[:force_mobile] || @mobile
    month_year = search_card_transaction_params[:month_year]
    user_card_id = card_transaction_params[:user_card_id].presence

    card_installments = Logic::CardInstallments.find_ref_month_year_by_params(current_user, card_transaction_params, search_card_transaction_params)

    render Views::CardTransactions::MonthYear.new(mobile:, month_year:, user_card_id:, card_installments:)
  end

  def show; end

  def new
    @card_transaction = current_user.card_transactions.new(
      user_card_id: params[:user_card_id] || current_user.user_cards.active.order(:user_card_name).first.id,
      date: Time.zone.now
    )
    @card_transaction.entity_transactions.build(entity_id: card_transaction_params[:entity_id]) if card_transaction_params[:entity_id]
    @card_transaction.build_month_year

    respond_to do |format|
      format.html { render Views::CardTransactions::New.new(current_user:, card_transaction: @card_transaction) }
      format.turbo_stream
    end
  end

  def edit
    @card_transaction = current_user.card_transactions.find(params[:id])

    respond_to do |format|
      format.html { render Views::CardTransactions::Edit.new(current_user:, card_transaction: @card_transaction) }
      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction&.user_card&.user_card_name)
      end
    end
  end

  def create
    @card_transaction = current_user.card_transactions.new(card_transaction_params.merge(imported: false))
    @card_transaction.build_month_year if @card_transaction.user_card_id

    first_installment = @card_transaction.card_installments.first
    @card_transaction.card_installments.each_with_index do |ci, index|
      # next if ci.paid

      ref_date = Date.new(first_installment.year, first_installment.month, 1) + index.months

      ci.date  = @card_transaction.date + index.months
      ci.year  = ref_date.year
      ci.month = ref_date.month
    end

    handle_save
  end

  def update
    @card_transaction.assign_attributes(card_transaction_params.merge(imported: false))
    @card_transaction.build_month_year if @card_transaction.user_card_id

    handle_save
  end

  def destroy
    @user_card = @card_transaction.user_card
    @card_transaction.destroy
    index
    @index_context[:default_year] = @card_transaction.year
    @index_context[:active_month_years] = [ Date.new(@card_transaction.year, @card_transaction.month).strftime("%Y%m").to_i ]

    respond_to(&:turbo_stream)
  end

  def duplicate
    @card_transaction = CardTransaction.duplicate(params[:id])

    render Views::CardTransactions::New.new(current_user:, card_transaction: @card_transaction)
  end

  def handle_save # rubocop:disable Metrics/AbcSize
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
        @index_context[:user_card] = @card_transaction.user_card
        @index_context[:default_year] = @card_transaction.year
        @index_context[:active_month_years] = @card_transaction.card_installments.map { |i| Date.new(i.year, i.month).strftime("%Y%m").to_i }.uniq
        @index_context[:search_term] = @card_transaction.description

        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end

      respond_to(&:turbo_stream)
    end
  end

  def pay_in_advance
    description = model_attribute(CardTransaction, :card_advance_description)

    @card_transaction = CardTransaction.new_advanced_payment(current_user, card_transaction_params.merge(description:))
    @card_transaction.card_installments.first.assign_attributes(@card_transaction.slice(:year, :month))
    @card_transaction.save

    @user_card = current_user.user_cards.find_by(id: card_transaction_params[:user_card_id])
    build_index_context(@user_card.card_installments)
    @index_context[:active_month_years] = [ Date.new(@card_transaction.year, @card_transaction.month).strftime("%Y%m").to_i ]

    respond_to do |format|
      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name)
      end
    end
  end

  def build_index_context(card_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || (Time.zone.today + 1.month)
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || (Time.zone.today + 1.month)
    default_active_month_years = [ [ max_date, Time.zone.today + 1.month ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)

    card_installment_ids = [ card_transaction_params[:card_installment_ids] ].flatten&.compact_blank
    category_id = [ card_transaction_params[:category_id] ].flatten&.compact_blank
    entity_id = [ card_transaction_params[:entity_id] ].flatten&.compact_blank
    search_term = search_card_transaction_params[:search_term]
    from_ct_price = search_card_transaction_params[:from_ct_price]
    to_ct_price = search_card_transaction_params[:to_ct_price]
    from_price = search_card_transaction_params[:from_price]
    to_price = search_card_transaction_params[:to_price]
    from_installments_count = search_card_transaction_params[:from_installments_count]
    to_installments_count = search_card_transaction_params[:to_installments_count]
    force_mobile = search_card_transaction_params[:force_mobile]

    if params[:all_month_years]
      associations = {}
      associations.merge!({ categories: { id: category_id } }) if category_id.present?
      associations.merge!({ entities: { id: entity_id } })     if entity_id.present?

      card_installments
        .joins(card_transaction: associations.keys)
        .where(card_transaction: associations).map { |i| Date.new(i.year, i.month).strftime("%Y%m").to_i }
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
      card_installment_ids:,
      category_id:,
      entity_id:,
      from_ct_price:,
      to_ct_price:,
      from_price:,
      to_price:,
      from_installments_count:,
      to_installments_count:,
      user_card: @user_card,
      force_mobile:
    }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @card_transaction = current_user.card_transactions.find(params[:id])
  end

  def search_card_transaction_params
    params.permit(
      %i[
        search_term
        from_ct_price
        to_ct_price
        from_price
        to_price
        from_installments_count
        to_installments_count
        month_year
        force_mobile
      ]
    )
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    return {} if params[:card_transaction].blank?

    params.require(:card_transaction).permit(
      %i[id description comment date month year price paid user_id user_card_id category_id entity_id],
      card_installment_ids: [], category_id: [], entity_id: [],
      category_transactions_attributes: %i[id category_id _destroy],
      card_installments_attributes: %i[id number date month year price _destroy],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price, :price_to_be_returned, :_destroy,
        { exchanges_attributes: %i[id number exchange_type bound_type price _destroy] }
      ]
    )
  end
end
