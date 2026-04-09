# frozen_string_literal: true

class CardTransactionsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include TabsConcern

  before_action :set_card_transaction, only: %i[edit update destroy]
  before_action :set_card_tabs, except: :index

  def index
    @user_card = current_user.user_cards.find_by(id: params[:user_card_id]) if params[:user_card_id]
    @user_card ||= current_user.user_cards.find_by(id: card_transaction_params[:user_card_id])

    build_index_context(card_installments_for_selected_user_card)

    set_card_tabs

    respond_to do |format|
      format.html { render Views::CardTransactions::Index.new(index_context: @index_context, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def search
    build_index_context(current_context.card_installments)

    respond_to do |format|
      format.html { render Views::CardTransactions::Index.new(index_context: @index_context, search: true, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def month_year
    mobile = search_card_transaction_params[:force_mobile] || @mobile
    month_year = search_card_transaction_params[:month_year]
    user_card_id = card_transaction_params[:user_card_id].presence

    card_installments = Logic::CardInstallments.find_ref_month_year_by_params(current_context, card_transaction_params, search_card_transaction_params)

    render Views::CardTransactions::MonthYear.new(mobile:, month_year:, user_card_id:, card_installments:)
  end

  def show; end

  def new
    @card_transaction = current_context.card_transactions.new(
      user: current_user,
      user_card_id: params[:user_card_id] || current_user.user_cards.active.order(:user_card_name).first.id,
      date: Time.zone.now
    )
    @card_transaction.entity_transactions.build(entity_id: card_transaction_params[:entity_id]) if card_transaction_params[:entity_id]
    @card_transaction.build_month_year
    @chain_context = current_chain_context(mode: "create")

    respond_to do |format|
      format.html { render Views::CardTransactions::New.new(current_user:, card_transaction: @card_transaction, chain_context: @chain_context) }
      format.turbo_stream
    end
  end

  def edit
    @card_transaction = current_context.card_transactions.find(params[:id])

    respond_to do |format|
      format.html { render Views::CardTransactions::Edit.new(current_user:, card_transaction: @card_transaction) }
      format.turbo_stream
    end
  end

  def create
    @card_transaction = current_context.card_transactions.new(assignable_card_transaction_params.merge(user: current_user, imported: false))

    if finish_chain_without_save_requested?
      handle_chain_finish_without_save
      return
    end

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
    @card_transaction.edit_phase = true if card_transaction_params[:card_installments_attributes].present?
    @card_transaction.assign_attributes(assignable_card_transaction_params.merge(imported: false))
    @card_transaction.build_month_year if @card_transaction.user_card_id

    handle_save
  end

  def destroy
    @card_transaction.historical_correction_confirmation = params[:historical_correction_confirmation]
    card_installment = CardInstallment.find_by(id: params[:card_installment_id]) || @card_transaction.card_installments.first

    @user_card = @card_transaction.user_card
    earliest_installment = @card_transaction.card_installments.order(:date).first
    @card_transaction.update_columns(date: earliest_installment.date) if earliest_installment.present?
    destroyed = @card_transaction.destroy

    if destroyed
      index
      @index_context[:default_year] = card_installment.year
      @index_context[:active_month_years] = [ Date.new(card_installment.year, card_installment.month).strftime("%Y%m").to_i ]
    end

    respond_to do |format|
      format.turbo_stream do
        render :destroy, status: destroyed ? :ok : :unprocessable_content
      end
    end
  end

  def duplicate
    @card_transaction = build_duplicate_card_transaction(params[:id])

    set_card_tabs
    @chain_context = current_chain_context(mode: "duplicate")

    render Views::CardTransactions::New.new(current_user:, card_transaction: @card_transaction, chain_context: @chain_context)
  end

  def handle_save
    if params[:commit] == "Update"
      @chain_context = current_chain_context

      respond_to do |format|
        format.turbo_stream do
          set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)

          render turbo_stream: [
            turbo_stream.update(
              @card_transaction,
              Views::CardTransactions::Form.new(current_user: @current_user, card_transaction: @card_transaction, chain_context: @chain_context)
            ),
            turbo_stream.update(:tabs, partial: "shared/tabs")
          ], status: :ok
        end
      end
    else
      saved = @card_transaction.save
      normalize_failed_card_transaction_save! unless saved

      if saved
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
        handle_chain_save_success
      else
        @chain_context = current_chain_context
      end

      respond_to do |format|
        format.turbo_stream do
          render action_name, status: saved ? :ok : :unprocessable_content
        end
      end
    end
  end

  def pay_in_advance
    description = model_attribute(CardTransaction, :card_advance_description)

    @card_transaction = CardTransaction.new_advanced_payment(current_user, card_transaction_params.merge(description:), context: current_context)
    @card_transaction.card_installments.first.assign_attributes(@card_transaction.slice(:year, :month))
    @card_transaction.save

    @user_card = current_user.user_cards.find_by(id: card_transaction_params[:user_card_id])
    build_index_context(card_installments_for_selected_user_card)
    @index_context[:active_month_years] = [ Date.new(@card_transaction.year, @card_transaction.month).strftime("%Y%m").to_i ]

    respond_to(&:turbo_stream)
  end

  def add_to_subscription
    @subscription = current_context.subscriptions.find_by(id: params[:subscription_id])
    return render_bulk_subscription_failure(I18n.t("bulk_actions.invalid_subscription")) if @subscription.blank?

    transactions = selected_card_transactions_for_bulk_subscription
    return render_bulk_subscription_failure(I18n.t("bulk_actions.empty_selection")) if transactions.empty?

    failed_transaction = nil

    ActiveRecord::Base.transaction do
      @subscription.attach_transactions!(transactions)
    rescue ActiveRecord::RecordInvalid => e
      failed_transaction = e.record
      raise ActiveRecord::Rollback
    end

    return render_bulk_subscription_failure(notification_model_or_history_lock(failed_transaction, :not_updateda, CardTransaction)) if failed_transaction.present?

    build_index_context_from_selection? || build_index_context(card_installments_for_selected_user_card)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CardTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: I18n.t("notification.added_to_subscription") })
        ]
      end
    end
  end

  def build_index_context(card_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    today = Time.zone.today
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || (today + 1.month)
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || (today + 1.month)

    if @user_card && max_date > today

      reference = current_context.references.where(user_card: @user_card, reference_closing_date: [ Date.tomorrow.. ]).order(:reference_closing_date).first

      if reference
        month_year_reference = Date.new(reference.year, reference.month)
        [ month_year_reference.strftime("%Y%m").to_i ]
      else
        [ [ today, max_date ].min.strftime("%Y%m").to_i ]
      end
    else
      [ [ today, max_date ].min.strftime("%Y%m").to_i ]
    end => default_active_month_years

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
    from_installments_number = search_card_transaction_params[:from_installments_number]
    to_installments_number = search_card_transaction_params[:to_installments_number]
    force_mobile = search_card_transaction_params[:force_mobile]
    order_by = search_card_transaction_params[:order_by]

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

    count_by_month_year = Logic::CardInstallments.find_count_based_on_search(
      current_context,
      card_transaction_params.merge(user_card_id: @user_card&.id || []),
      search_card_transaction_params
    )

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
      from_installments_number:,
      to_installments_number:,
      user_card: @user_card,
      user_card_id: @user_card&.id,
      force_mobile:,
      order_by:,
      count_by_month_year:,
      available_subscriptions: current_context.subscriptions.order(:description).to_a
    }
  end

  private

  def set_card_tabs
    set_tabs(active_menu: :card, active_sub_menu: card_tab_name_for_state)
  end

  def build_index_context_from_selection? # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    return false if params[:index_context_json].blank?

    context = JSON.parse(params[:index_context_json]).with_indifferent_access
    card_installments = current_context.card_installments
    today = Time.zone.today
    min_date = card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || (today + 1.month)
    max_date = card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || (today + 1.month)
    years = (min_date.year..max_date.year)

    selected_user_card_id = context[:user_card_id].presence || context.dig(:user_card, :id) || context.dig(:user_card, "id")
    @user_card = current_user.user_cards.find_by(id: selected_user_card_id) if selected_user_card_id.present?

    card_installment_ids = Array(context[:card_installment_ids]).compact_blank
    category_id = Array(context[:category_id]).compact_blank
    entity_id = Array(context[:entity_id]).compact_blank
    search_term = context[:search_term]
    from_ct_price = context[:from_ct_price]
    to_ct_price = context[:to_ct_price]
    from_price = context[:from_price]
    to_price = context[:to_price]
    from_installments_count = context[:from_installments_count]
    to_installments_count = context[:to_installments_count]
    from_installments_number = context[:from_installments_number]
    to_installments_number = context[:to_installments_number]
    order_by = context[:order_by]
    force_mobile = ActiveModel::Type::Boolean.new.cast(context[:force_mobile])
    active_month_years = Array(context[:active_month_years]).map(&:to_i)
    default_year = context[:default_year].presence&.to_i
    default_year ||= active_month_years.max.to_s.first(4).to_i if active_month_years.any?
    default_year ||= [ max_date, today ].min.year

    count_by_month_year = Logic::CardInstallments.find_count_based_on_search(
      current_context,
      {
        card_installment_ids:,
        user_card_id: @user_card&.id || [],
        category_id:,
        entity_id:
      },
      {
        search_term:,
        from_ct_price:,
        to_ct_price:,
        from_price:,
        to_price:,
        from_installments_count:,
        to_installments_count:,
        from_installments_number:,
        to_installments_number:,
        force_mobile:,
        order_by:
      }
    )

    @mobile = force_mobile
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
      from_installments_number:,
      to_installments_number:,
      user_card: @user_card,
      user_card_id: @user_card&.id,
      force_mobile:,
      order_by:,
      count_by_month_year:,
      available_subscriptions: current_context.subscriptions.order(:description).to_a
    }

    true
  end

  def handle_chain_save_success
    created_record_ids = updated_chain_record_ids(@card_transaction.id)

    if continue_chain?
      @chain_context = current_chain_context(record_ids: created_record_ids, checked: true)
      @next_card_transaction = next_card_transaction_for_chain
      return
    end

    index
    @index_context[:user_card] = @card_transaction.user_card
    apply_chain_index_context(record_ids: created_record_ids)
  end

  def handle_chain_finish_without_save
    @finished_chain_without_save = true
    index
    @index_context[:user_card] = @card_transaction.user_card if @card_transaction.user_card.present?
    apply_chain_index_context(record_ids: current_chain_record_ids)

    respond_to do |format|
      format.turbo_stream { render :create, status: :ok }
    end
  end

  def apply_chain_index_context(record_ids:)
    card_transactions = current_context.card_transactions.includes(:card_installments).where(id: record_ids)
    installment_ids = card_transactions.flat_map { |transaction| transaction.card_installments.pluck(:id) }.uniq
    active_month_years = card_transactions.flat_map do |transaction|
      transaction.card_installments.map { |installment| Date.new(installment.year, installment.month).strftime("%Y%m").to_i }
    end.uniq

    @index_context[:card_installment_ids] = installment_ids
    @index_context[:active_month_years] = active_month_years.presence || @index_context[:active_month_years]
    @index_context[:default_year] = active_month_years.max.to_s.first(4).to_i if active_month_years.present?
  end

  def next_card_transaction_for_chain
    if current_chain_context[:mode] == "duplicate"
      build_duplicate_card_transaction(@card_transaction.id)
    else
      current_context.card_transactions.new(
        user: current_user,
        user_card_id: @card_transaction.user_card_id || current_user.user_cards.active.order(:user_card_name).first.id,
        date: Time.zone.now
      ).tap(&:build_month_year)
    end
  end

  def build_duplicate_card_transaction(id)
    CardTransaction.duplicate(id).tap do |card_transaction|
      card_transaction.price = 0
      card_transaction.card_installments.each { |installment| installment.price = 0 }
    end
  end

  def current_chain_context(mode: nil, record_ids: current_chain_record_ids, checked: continue_chain_requested?)
    {
      mode: mode || params[:chain_mode].presence || "create",
      record_ids:,
      checked:
    }
  end

  def current_chain_record_ids
    Array(params[:chain_record_ids]).compact_blank.map(&:to_i)
  end

  def updated_chain_record_ids(current_record_id)
    (current_chain_record_ids + [ current_record_id ]).uniq
  end

  def continue_chain?
    continue_chain_requested? && !finish_chain_requested?
  end

  def continue_chain_requested?
    ActiveModel::Type::Boolean.new.cast(params[:continue_chain])
  end

  def finish_chain_requested?
    ActiveModel::Type::Boolean.new.cast(params[:finish_chain])
  end

  def finish_chain_without_save_requested?
    ActiveModel::Type::Boolean.new.cast(params[:finish_chain_without_save])
  end

  def card_tab_name_for_state
    selected_user_card_for_tabs&.user_card_name || @card_transaction&.user_card&.user_card_name || :search
  end

  def selected_user_card_for_tabs
    @user_card || current_user.user_cards.find_by(id: params[:user_card_id] || params.dig(:card_transaction, :user_card_id))
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @card_transaction = current_context.card_transactions.find(params[:id])
  end

  def card_installments_for_selected_user_card
    return current_context.card_installments unless @user_card

    current_context.card_installments.joins(:card_transaction).where(card_transactions: { user_card_id: @user_card.id })
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
        from_installments_number
        to_installments_number
        month_year
        force_mobile
        order_by
      ]
    )
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    return {} if params[:card_transaction].blank?

    params.require(:card_transaction).permit(
      %i[id description comment date month year price paid user_id user_card_id category_id entity_id duplicate subscription_id historical_correction_confirmation],
      card_installment_ids: [], category_id: [], entity_id: [],
      category_transactions_attributes: %i[id category_id _destroy],
      card_installments_attributes: %i[id number date month year price _destroy],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price, :price_to_be_returned, :_destroy,
        { exchanges_attributes: %i[id number exchange_type bound_type price date month year _destroy] }
      ]
    )
  end

  def assignable_card_transaction_params
    deduplicated_card_transaction_params(card_transaction_params.to_h.with_indifferent_access)
  end

  def normalize_failed_card_transaction_save!
    propagate_nested_history_errors!
    @card_transaction.errors.add(:base, :invalid) if @card_transaction.errors.empty?
  end

  def propagate_nested_history_errors!
    [ *@card_transaction.card_installments, *@card_transaction.entity_transactions, *@card_transaction.entity_transactions.flat_map(&:exchanges) ].each do |record|
      Array(record.errors.details[:base]).each do |detail|
        @card_transaction.errors.add(:base, detail[:error])
      end
    end
  end

  def deduplicated_card_transaction_params(attributes)
    attributes.merge(
      category_transactions_attributes: deduplicate_nested_attributes(attributes[:category_transactions_attributes], key: :category_id),
      entity_transactions_attributes: deduplicate_nested_attributes(attributes[:entity_transactions_attributes], key: :entity_id)
    )
  end

  def deduplicate_nested_attributes(attributes, key:)
    seen_values = {}

    normalized_nested_attributes(attributes).filter_map do |entry|
      next entry if entry.blank?

      normalized_entry = entry.with_indifferent_access
      next normalized_entry if ActiveModel::Type::Boolean.new.cast(normalized_entry[:_destroy])

      nested_value = normalized_entry[key].presence
      next normalized_entry if nested_value.blank?
      next if seen_values[nested_value.to_s]

      seen_values[nested_value.to_s] = true
      normalized_entry
    end
  end

  def normalized_nested_attributes(attributes)
    return [] if attributes.blank?

    raw_attributes =
      if attributes.respond_to?(:to_unsafe_h)
        attributes.to_unsafe_h
      else
        attributes
      end

    collection =
      case raw_attributes
      when Hash
        indexed_nested_attributes_hash?(raw_attributes) ? raw_attributes.values : [ raw_attributes ]
      else
        Array(raw_attributes)
      end

    collection.map do |entry|
      entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
    end
  end

  def indexed_nested_attributes_hash?(attributes)
    attributes.keys.all? { |nested_key| nested_key.to_s.match?(/\A\d+\z/) }
  end

  def selected_card_transactions_for_bulk_subscription
    current_context.card_transactions.where(id: Array(params[:ids].to_s.split(",")).compact_blank).to_a
  end

  def render_bulk_subscription_failure(alert_message)
    build_index_context_from_selection? || build_index_context(card_installments_for_selected_user_card)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CardTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: alert_message })
        ], status: :unprocessable_content
      end
    end
  end
end
