# frozen_string_literal: true

class CashTransactionsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include TabsConcern

  before_action :set_cash_transaction, only: %i[edit update destroy]
  before_action :set_cash_tabs

  def index
    build_index_context(current_user.cash_installments)

    respond_to do |format|
      format.html { render Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def month_year
    mobile = search_cash_transaction_params[:force_mobile] || @mobile
    month_year = search_cash_transaction_params[:month_year]

    cash_installments, budgets = Logic::CashTransactions.find_by_ref_month_year(current_user, cash_transaction_params, search_cash_transaction_params)

    render Views::CashTransactions::MonthYear.new(
      mobile:,
      month_year:,
      cash_installments:,
      budgets:,
      index_context: month_year_index_context(mobile)
    )
  end

  def show; end

  def new
    user_bank_account_id = params[:user_bank_account_id] || current_user.user_bank_accounts.active.first&.id
    @cash_transaction = current_user.cash_transactions.new(user_bank_account_id:, date: Time.zone.now)
    handle_params

    respond_to do |format|
      format.html { render Views::CashTransactions::New.new(current_user:, cash_transaction: @cash_transaction) }
      format.turbo_stream
    end
  end

  def edit
    @cash_transaction = current_user.cash_transactions.find(params[:id])
    handle_params

    respond_to do |format|
      format.html { render Views::CashTransactions::Edit.new(current_user:, cash_transaction: @cash_transaction) }
      format.turbo_stream
    end
  end

  def create
    @cash_transaction = current_user.cash_transactions.new(assignable_cash_transaction_params.merge(imported: false))
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id

    handle_save
  end

  def update
    @cash_transaction.assign_attributes(assignable_cash_transaction_params.merge(imported: false))
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id
    @cash_transaction.update_installments if params[:commit] == "Update"

    handle_save
  end

  def destroy
    @user_bank_account = @cash_transaction.user_bank_account
    @cash_transaction.update_columns(date: @cash_transaction.cash_installments.order(:date).first.date)
    @cash_transaction.destroy
    mark_source_message_applied
    index

    respond_to(&:turbo_stream)
  end

  def handle_params
    assign_message_context
    handle_category_params
    handle_entity_params

    if cash_transaction_params[:cash_installments_attributes].present?
      @cash_transaction.edit_phase = true if @cash_transaction.persisted?

      @cash_transaction.cash_installments.each(&:mark_for_destruction)

      @cash_transaction.cash_installments_attributes = cash_transaction_params[:cash_installments_attributes]
      @cash_transaction.description = cash_transaction_params[:description]
      @cash_transaction.price = cash_transaction_params[:price]
      @cash_transaction.date = cash_transaction_params[:date]
      @cash_transaction.month = cash_transaction_params[:month]
      @cash_transaction.year = cash_transaction_params[:year]

    elsif @cash_transaction.new_record?
      @cash_transaction.build_month_year
    end
  end

  def handle_category_params
    return if cash_transaction_params[:category_id].nil?

    new_category_id = cash_transaction_params[:category_id].to_i
    current_category_ids = @cash_transaction.category_transactions.reject(&:marked_for_destruction?).map(&:category_id).sort
    return if current_category_ids == [ new_category_id ]

    if replaying_reference_transaction? || (@cash_transaction.persisted? && current_category_ids.one?)
      @cash_transaction.category_transactions.each(&:mark_for_destruction)
    end

    @cash_transaction.category_transactions.build(category_id: new_category_id)
  end

  def handle_entity_params # rubocop:disable Metrics/AbcSize
    if cash_transaction_params[:entity_id].present?
      return if @cash_transaction.entity_transactions.pluck(:entity_id).include?(cash_transaction_params[:entity_id].to_i)

      @cash_transaction.entity_transactions.build(entity_id: cash_transaction_params[:entity_id])
    elsif cash_transaction_params[:entity_transactions_attributes].present?
      current_entities = @cash_transaction.entity_transactions.pluck(:entity_id)
      new_entities = cash_transaction_params[:entity_transactions_attributes].pluck(:entity_id).map(&:to_i)
      if @cash_transaction.entity_transactions.one? && current_entities == new_entities # means it is persisted
        @cash_transaction.entity_transactions.each do |entity_transaction|
          entity_transactions_attributes = cash_transaction_params[:entity_transactions_attributes].find do |a|
            a[:entity_id].to_i == entity_transaction.entity_id
          end

          entity_transaction.assign_attributes(entity_transactions_attributes.except(:exchanges_attributes))
          synchronize_entity_transaction_exchanges(entity_transaction, entity_transactions_attributes[:exchanges_attributes])
        end
      else
        @cash_transaction.entity_transactions.each(&:mark_for_destruction)
        @cash_transaction.entity_transactions_attributes = cash_transaction_params[:entity_transactions_attributes]
      end
    end
  end

  def synchronize_entity_transaction_exchanges(entity_transaction, exchanges_attributes)
    exchanges_attributes = Array(exchanges_attributes)
    existing_exchanges_by_number = entity_transaction.exchanges.index_by(&:number)

    entity_transaction.exchanges.each do |exchange|
      new_attributes = exchanges_attributes.find { |attrs| attrs[:number].to_i == exchange.number }

      if new_attributes.present?
        exchange.assign_attributes(new_attributes)
      else
        exchange.mark_for_destruction
      end
    end

    exchanges_attributes.each do |exchange_attributes|
      next if existing_exchanges_by_number.key?(exchange_attributes[:number].to_i)

      entity_transaction.exchanges.build(exchange_attributes)
    end
  end

  def replaying_reference_transaction?
    cash_transaction_params[:reference_transactable_id].present?
  end

  def assign_message_context
    @cash_transaction.source_message_id = cash_transaction_params[:source_message_id]
  end

  def assignable_cash_transaction_params
    cash_transaction_params.except(:source_message_id)
  end

  def source_message_id
    @cash_transaction&.source_message_id.presence || cash_transaction_params[:source_message_id].presence || params[:message_id].presence
  end

  def source_message
    return if source_message_id.blank?

    @source_message ||= current_user.received_messages.find_by(id: source_message_id)
  end

  def mark_source_message_applied
    source_message&.update!(applied_at: Time.current)
  end

  def handle_save
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
        mark_source_message_applied
        index
        @index_context[:default_year] = @cash_transaction.cash_installments.first.year
        @index_context[:active_month_years] = @cash_transaction.cash_installments.map { |i| Date.new(i.year, i.month).strftime("%Y%m").to_i }.uniq
        @index_context[:user_bank_account_id] = []
      end

      respond_to(&:turbo_stream)
    end
  end

  def build_index_context(cash_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
    today_zn = Time.zone.today.beginning_of_month

    min_year = cash_installments.minimum("installments.year") || today_zn.year
    max_year = cash_installments.maximum("installments.year") || today_zn.year
    years = (min_year..max_year)

    default_active_month_years =
      cash_installments.where(paid: false, year: ..today_zn.year, month: ..today_zn.month)
                       .group(:year, :month)
                       .pluck(:year, :month)
                       .map { |y, m| Date.new(y, m).strftime("%Y%m").to_i }

    default_active_month_years = [ today_zn.strftime("%Y%m").to_i ] if default_active_month_years.empty?

    category_id = [ cash_transaction_params[:category_id] ].flatten&.compact_blank
    entity_id = [ cash_transaction_params[:entity_id] ].flatten&.compact_blank
    cash_installment_ids = [ cash_transaction_params[:cash_installment_ids] ].flatten&.compact_blank
    user_bank_account_id = [ cash_transaction_params[:user_bank_account_id] ].flatten&.compact_blank
    search_term = search_cash_transaction_params[:search_term]
    from_ct_price = search_cash_transaction_params[:from_ct_price]
    to_ct_price = search_cash_transaction_params[:to_ct_price]
    from_price = search_cash_transaction_params[:from_price]
    to_price = search_cash_transaction_params[:to_price]
    from_installments_count = search_cash_transaction_params[:from_installments_count]
    to_installments_count = search_cash_transaction_params[:to_installments_count]
    from_date = search_cash_transaction_params[:from_date]
    to_date = search_cash_transaction_params[:to_date]
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
    default_year = (active_month_years.max.to_s.first(4) || params[:default_year])&.to_i || Time.zone.today.year

    if action_name.in? %w[create update]
      Logic::CashTransactions.find_count_based_on_search(current_user, {}, {})
    else
      Logic::CashTransactions.find_count_based_on_search(current_user, cash_transaction_params, search_cash_transaction_params)
    end => count_by_month_year

    @index_context = {
      current_user:,
      years:,
      default_year:,
      active_month_years:,
      search_term:,
      category_id:,
      entity_id:,
      cash_installment_ids:,
      user_bank_account_id:,
      from_ct_price:,
      to_ct_price:,
      from_price:,
      to_price:,
      from_installments_count:,
      to_installments_count:,
      from_date:,
      to_date:,
      user_card: @user_card,
      paid:,
      pending:,
      skip_budgets:,
      force_mobile:,
      count_by_month_year:
    }
  end

  private

  def set_cash_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :pix)
  end

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
        from_date
        to_date
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
      %i[
        id description comment date month year price paid user_id user_bank_account_id
        reference_transactable_type reference_transactable_id category_id entity_id subscription_id friend_notification_intent source_message_id
      ],
      user_bank_account_id: [], category_id: [], entity_id: [], cash_installment_ids: [],
      category_transactions_attributes: %i[id category_id _destroy],
      cash_installments_attributes: %i[id number date month year price paid _destroy],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price, :price_to_be_returned, :exchanges_count, :_destroy,
        { exchanges_attributes: %i[id number exchange_type bound_type price date month year _destroy] }
      ]
    )
  end

  def month_year_index_context(mobile) # rubocop:disable Metrics/AbcSize
    {
      default_year: params[:default_year],
      active_month_years: params[:active_month_years].present? ? JSON.parse(params[:active_month_years]).map(&:to_i) : [],
      search_term: search_cash_transaction_params[:search_term],
      category_id: [ cash_transaction_params[:category_id] ].flatten.compact_blank,
      entity_id: [ cash_transaction_params[:entity_id] ].flatten.compact_blank,
      cash_installment_ids: [ cash_transaction_params[:cash_installment_ids] ].flatten.compact_blank,
      user_bank_account_id: [ cash_transaction_params[:user_bank_account_id] ].flatten.compact_blank,
      from_ct_price: search_cash_transaction_params[:from_ct_price],
      to_ct_price: search_cash_transaction_params[:to_ct_price],
      from_price: search_cash_transaction_params[:from_price],
      to_price: search_cash_transaction_params[:to_price],
      from_installments_count: search_cash_transaction_params[:from_installments_count],
      to_installments_count: search_cash_transaction_params[:to_installments_count],
      from_date: search_cash_transaction_params[:from_date],
      to_date: search_cash_transaction_params[:to_date],
      paid: search_cash_transaction_params[:paid],
      pending: search_cash_transaction_params[:pending],
      skip_budgets: search_cash_transaction_params[:skip_budgets],
      force_mobile: mobile
    }
  end
end
