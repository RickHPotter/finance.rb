# frozen_string_literal: true

class LalasController < ApplicationController
  include TranslateHelper

  skip_before_action :authenticate_user!
  before_action :set_user_agent, :set_tabs

  def index
    render Views::Lalas::Index.new
  end

  def card_transactions
    @user_card = User.first.user_cards.find_by(id: params[:user_card_id]) if params[:user_card_id]
    @user_card ||= User.first.user_cards.find_by(id: card_transaction_params[:user_card_id])

    card_build_index_context(@user_card.card_installments)

    respond_to do |format|
      format.html do
        render Views::Lalas::CardTransactions::Index.new(index_context: @index_context)
      end

      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name || :search)
      end
    end
  end

  def cash_transactions
    cash_build_index_context(User.first.cash_installments)

    respond_to do |format|
      format.html do
        render Views::Lalas::CashTransactions::Index.new(index_context: @index_context)
      end

      format.turbo_stream do
        set_tabs(active_menu: :cash, active_sub_menu: :pix)
      end
    end
  end

  def card_transactions_month_year
    mobile = search_card_transaction_params[:force_mobile] || @mobile
    month_year = search_card_transaction_params[:month_year]
    user_card_id = card_transaction_params[:user_card_id].presence

    card_installments = Logic::CardInstallments.find_ref_month_year_by_params(User.first, card_transaction_params, search_card_transaction_params)

    render Views::Lalas::CardTransactions::MonthYear.new(mobile:, month_year:, user_card_id:, card_installments:)
  end

  def cash_transactions_month_year
    mobile = search_cash_transaction_params[:force_mobile] || @mobile
    month_year = search_cash_transaction_params[:month_year]
    month_year_str = I18n.l(Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01"), format: "%B %Y")

    cash_installments, = Logic::CashTransactions.find_by_ref_month_year(User.first, cash_transaction_params, search_cash_transaction_params)

    render Views::Lalas::CashTransactions::MonthYear.new(mobile:, month_year:, month_year_str:, cash_installments:)
  end

  def card_build_index_context(card_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || (Time.zone.today + 1.month)
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || (Time.zone.today + 1.month)
    default_active_month_years = [ [ max_date, Time.zone.today + 1.month ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)

    card_installment_ids = [ card_transaction_params[:card_installment_ids] ].flatten&.compact_blank
    category_id = User.first.categories.where(category_name: [ "EXCHANGE", "EXCHANGE RETURN", "BORROW RETURN" ]).ids
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
      force_mobile:
    }
  end

  def cash_build_index_context(cash_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    min_date = cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    max_date = cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
    default_active_month_years = [ Time.zone.today.clamp(min_date, max_date).strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)

    category_id = User.first.categories.where(category_name: [ "EXCHANGE", "EXCHANGE RETURN", "BORROW RETURN" ]).ids
    entity_id = User.first.entities.where(entity_name: "LALA").ids
    user_bank_account_id = [ cash_transaction_params[:user_bank_account_id] ].flatten&.compact_blank
    search_term = search_cash_transaction_params[:search_term]
    paid = ActiveModel::Type::Boolean.new.cast(search_cash_transaction_params[:paid])
    pending = ActiveModel::Type::Boolean.new.cast(search_cash_transaction_params[:pending])
    skip_budgets = search_cash_transaction_params[:skip_budgets]
    force_mobile = search_cash_transaction_params[:force_mobile]

    active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
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
      user_card: @user_card,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:
    }
  end

  def set_user_agent
    return unless request.user_agent =~ /Mobile|Android|iPhone|iPad/

    @mobile = true
  end

  def set_tabs(active_menu: :cash, active_sub_menu: :pix)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu

    set_variables
  end

  private

  def set_variables
    @main_items = [ { label: t("tabs.pix"), icon: :mobile, link: cash_transactions_lalas_path, default: @active_menu == :pix } ]

    card_items = User.first.user_cards.active.pluck(:id, :user_card_name).map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      { label: user_card_name, icon: :credit_card, link: card_transactions_lalas_path(user_card_id:), default: }
    end

    @main_items += card_items

    @main_items.first[:default] = true if @main_items.pluck(:default).uniq == [ false ]
    @main_items.map! { |item| item.slice(:label, :icon, :link, :default).values }

    @main_tab = @main_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile
  end

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

  def search_cash_transaction_params
    params.permit(
      %i[
        search_term
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
