# frozen_string_literal: true

# Controller for Unauthenticated User Lala
class Lalas::CardTransactionsController < LalasController
  include TranslateHelper

  def index
    @user_card = User.first.user_cards.find_by(id: params[:user_card_id]) if params[:user_card_id]
    @user_card ||= User.first.user_cards.find_by(id: card_transaction_params[:user_card_id])

    build_index_context(@user_card.card_installments)
    set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name || :search)

    respond_to do |format|
      format.html { render Views::Lalas::CardTransactions::Index.new(index_context: @index_context) }
      format.turbo_stream
    end
  end

  def month_year
    mobile = search_card_transaction_params[:force_mobile] || @mobile
    month_year = search_card_transaction_params[:month_year]
    user_card_id = card_transaction_params[:user_card_id].presence

    card_installments = Logic::CardInstallments.find_ref_month_year_by_params(User.first, card_transaction_params, search_card_transaction_params)

    render Views::Lalas::CardTransactions::MonthYear.new(mobile:, month_year:, user_card_id:, card_installments:)
  end

  def build_index_context(card_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || (Time.zone.today + 1.month)
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || (Time.zone.today + 1.month)
    default_active_month_years = [ [ max_date, Time.zone.today + 1.month ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)

    card_installment_ids = [ card_transaction_params[:card_installment_ids] ].flatten&.compact_blank
    category_id = User.first.categories.where(category_name: [ "EXCHANGE" ]).ids
    entity_id = User.first.entities.where(entity_name: "LALA").ids
    search_term = search_card_transaction_params[:search_term]
    from_ct_price = search_card_transaction_params[:from_ct_price]
    to_ct_price = search_card_transaction_params[:to_ct_price]
    from_price = search_card_transaction_params[:from_price]
    to_price = search_card_transaction_params[:to_price]
    from_installments_count = search_card_transaction_params[:from_installments_count]
    to_installments_count = search_card_transaction_params[:to_installments_count]
    force_mobile = search_card_transaction_params[:force_mobile]

    active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
    default_year = (active_month_years.max.to_s.first(4) || params[:default_year])&.to_i || [ max_date, Time.zone.today ].min.year

    count_by_month_year = Logic::CardInstallments.find_count_based_on_search(
      User.first,
      card_transaction_params.merge(user_card_id: @user_card&.id || [], category_id:, entity_id:),
      search_card_transaction_params
    )

    @index_context = {
      current_user: User.first,
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
      force_mobile:,
      count_by_month_year:
    }
  end

  private

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

  def search_card_transaction_params
    params.permit(
      %i[
        search_term
        month_year
        force_mobile
      ]
    )
  end
end
