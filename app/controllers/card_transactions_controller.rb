# frozen_string_literal: true

class CardTransactionsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include TabsConcern

  before_action :set_card_transaction, only: %i[show edit update destroy]
  before_action :set_card_tabs, except: :index

  def index
    @user_card = current_user.user_cards.find_by(id: params[:user_card_id]) if params[:user_card_id]
    @user_card ||= current_user.user_cards.find_by(id: card_transaction_params[:user_card_id])

    build_index_context(card_installments_for_selected_user_card)
    @index_context[:return_to] = card_navigation_return_param(request.fullpath)

    set_card_tabs

    render_top_level Views::CardTransactions::Index.new(index_context: @index_context, mobile: @mobile)
  end

  def search
    build_index_context(current_context.card_installments)
    @index_context[:return_to] = card_navigation_return_param(request.fullpath)

    render_top_level Views::CardTransactions::Index.new(index_context: @index_context, search: true, mobile: @mobile)
  end

  def month_year
    mobile = search_card_transaction_params[:force_mobile] || @mobile
    month_year = search_card_transaction_params[:month_year]
    return_to = card_navigation_return_param(params[:return_to])
    user_card_id = card_transaction_params[:user_card_id].presence
    user_card = current_user.user_cards.find_by(id: user_card_id)

    card_installments = Logic::CardInstallments.find_ref_month_year_by_params(current_context, card_transaction_params, search_card_transaction_params)

    render Views::CardTransactions::MonthYear.new(
      mobile:,
      month_year:,
      user_card:,
      card_installments:,
      current_context:,
      category_colour_display_mode:,
      return_to:
    )
  end

  def show
    set_return_to

    render_top_level Views::CardTransactions::Show.new(card_transaction: @card_transaction, return_to: @return_to)
  end

  def new
    @card_transaction = current_context.card_transactions.new(
      user: current_user,
      user_card_id: params[:user_card_id] || current_user.user_cards.active.order(:user_card_name).first.id,
      date: Time.zone.now
    )
    seed_transaction_associations
    @card_transaction.build_month_year
    @chain_context = current_chain_context(mode: "create")
    set_return_to

    render_top_level Views::CardTransactions::New.new(
      current_user:,
      card_transaction: @card_transaction,
      chain_context: @chain_context,
      return_to: @return_to
    )
  end

  def edit
    @card_transaction = current_context.card_transactions.find(params[:id])
    set_return_to

    render_top_level Views::CardTransactions::Edit.new(current_user:, card_transaction: @card_transaction, return_to: @return_to)
  end

  def create
    @card_transaction = current_context.card_transactions.new(assignable_card_transaction_params.merge(user: current_user, imported: false))

    if finish_chain_without_save_requested?
      handle_chain_finish_without_save
      return
    end

    @card_transaction.build_month_year if @card_transaction.user_card_id
    prune_exchange_entity_transactions_without_exchanges!

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
    capture_shared_return_counterpart_destroy_notifications!
    @card_transaction.edit_phase = true if card_transaction_params[:card_installments_attributes].present?
    @card_transaction.assign_attributes(assignable_card_transaction_params.merge(imported: false))
    @card_transaction.historical_correction_confirmation = card_transaction_params[:historical_correction_confirmation]
    @card_transaction.build_month_year if @card_transaction.user_card_id
    prune_exchange_entity_transactions_without_exchanges!

    handle_save
  end

  def destroy
    set_return_to
    @card_transaction.historical_correction_confirmation = params[:historical_correction_confirmation]
    earliest_installment = @card_transaction.card_installments.order(:date).first
    Audit::BulkMutation.update_columns!(@card_transaction, date: earliest_installment.date) if earliest_installment.present?
    destroyed = @card_transaction.destroy

    if destroyed
      redirect_to @return_to,
                  notice: notification_model(:destroyeda, CardTransaction),
                  status: :see_other
      return
    end

    respond_to do |format|
      format.html { render Views::CardTransactions::Show.new(card_transaction: @card_transaction, return_to: @return_to), status: :unprocessable_content }
      format.turbo_stream { render :destroy, status: :unprocessable_content }
    end
  end

  def duplicate
    @card_transaction = build_duplicate_card_transaction(params[:id])

    set_card_tabs
    @chain_context = current_chain_context(mode: "duplicate")
    set_return_to

    render_top_level Views::CardTransactions::New.new(
      current_user:,
      card_transaction: @card_transaction,
      chain_context: @chain_context,
      return_to: @return_to
    )
  end

  def handle_save
    return render_local_update if params[:commit] == "Update"

    saved = @card_transaction.save
    normalize_failed_card_transaction_save! unless saved
    @chain_context = current_chain_context
    set_return_to

    return render_successful_save if saved

    render_save_failure
  end

  def render_local_update
    @chain_context = current_chain_context
    set_return_to

    respond_to do |format|
      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)

        render turbo_stream: [
          turbo_stream.update(
            @card_transaction,
            Views::CardTransactions::Form.new(
              current_user: @current_user,
              card_transaction: @card_transaction,
              chain_context: @chain_context,
              return_to: @return_to
            )
          ),
          turbo_stream.update(:tabs, partial: "shared/tabs")
        ], status: :ok
      end
    end
  end

  def render_successful_save
    notify_shared_return_counterpart_updates!
    set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)

    redirect_to handle_chain_save_success,
                notice: notification_model(action_name == "create" ? :createda : :updateda, CardTransaction),
                status: :see_other
  end

  def pay_in_advance
    @user_card = current_user.user_cards.find_by(id: card_transaction_params[:user_card_id])
    payment_window = card_advance_payment_window
    payment_date = parsed_card_advance_date

    return render_card_advance_failure(I18n.t("card_advance.invalid_payment_window")) unless payment_window&.cover?(payment_date)
    return render_card_advance_failure(card_advance_save_failure_message) unless persist_card_advance(payment_date)

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

  def build_index_context(card_installments)
    @index_context = IndexState::CardTransactions.new(
      current_user:,
      current_context:,
      params:,
      card_installments:,
      user_card: @user_card,
      transaction_filters: card_transaction_params,
      search_filters: search_card_transaction_params
    ).to_h
  end

  private

  def seed_transaction_associations
    @card_transaction.category_transactions.build(category_id: card_transaction_params[:category_id]) if card_transaction_params[:category_id]
    @card_transaction.entity_transactions.build(entity_id: card_transaction_params[:entity_id]) if card_transaction_params[:entity_id]
  end

  def render_top_level(view)
    respond_to do |format|
      format.html { render view }
    end
  end

  def render_save_failure
    respond_to do |format|
      format.html do
        view =
          if action_name == "create"
            Views::CardTransactions::New.new(
              current_user:,
              card_transaction: @card_transaction,
              chain_context: @chain_context,
              return_to: @return_to
            )
          else
            Views::CardTransactions::Edit.new(current_user:, card_transaction: @card_transaction, return_to: @return_to)
          end

        render view, status: :unprocessable_content
      end
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def set_return_to
    @return_to = card_navigation_destination(params[:return_to])
  end

  def card_navigation_destination(raw)
    Navigation::CardTransactions.new(
      raw:,
      fallback: card_transactions_path,
      current_user:,
      current_context:
    ).destination
  end

  def card_navigation_return_param(raw)
    destination = card_navigation_destination(raw)

    destination unless destination == card_transactions_path
  end

  def card_advance_payment_window
    return if @user_card.blank?

    Logic::CardAdvancePaymentWindow.new(
      user_card: @user_card,
      context: current_context,
      month: card_transaction_params[:month],
      year: card_transaction_params[:year]
    )
  end

  def parsed_card_advance_date
    Time.zone.parse(card_transaction_params[:date].to_s)&.change(sec: 0, usec: 0)
  rescue ArgumentError, TypeError
    nil
  end

  def persist_card_advance(payment_date)
    saved = false
    ActiveRecord::Base.transaction do
      @card_transaction = CardTransaction.new_advanced_payment(current_user, card_advance_attributes(payment_date), context: current_context)
      @card_transaction.description = @card_transaction.card_advance_description
      @card_transaction.card_installments.first.assign_attributes(@card_transaction.slice(:year, :month))
      saved = @card_transaction.save

      raise ActiveRecord::Rollback unless saved
    end
    saved
  rescue ActiveRecord::RecordInvalid => e
    @card_transaction&.errors&.add(:base, e.message)
    false
  end

  def card_advance_attributes(payment_date)
    card_transaction_params.slice(:date, :month, :year, :price, :user_card_id).merge(date: payment_date)
  end

  def card_advance_save_failure_message
    errors = @card_transaction&.errors
    errors&.full_messages&.to_sentence.presence || I18n.t("card_advance.not_created")
  end

  def render_card_advance_failure(alert_message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          :notification,
          partial: "shared/flash",
          locals: { notice: nil, alert: alert_message }
        ), status: :unprocessable_content
      end
      format.html { render plain: alert_message, status: :unprocessable_content }
    end
  end

  def set_card_tabs
    set_tabs(active_menu: :card, active_sub_menu: card_tab_name_for_state)
  end

  def build_index_context_from_selection?
    return false if params[:index_context_json].blank?

    @index_context = IndexState::CardTransactions.new(
      current_user:,
      current_context:,
      params:,
      card_installments: current_context.card_installments,
      user_card: nil,
      transaction_filters: card_transaction_params,
      search_filters: search_card_transaction_params,
      selection_context: JSON.parse(params[:index_context_json])
    ).to_h
    @user_card = @index_context[:user_card]
    @mobile = @index_context[:force_mobile]

    true
  end

  def handle_chain_save_success
    created_record_ids = updated_chain_record_ids(@card_transaction.id)

    return chain_continuation_destination(created_record_ids) if continue_chain?
    return chain_index_destination(created_record_ids) if chain_workflow?

    @return_to
  end

  def notify_shared_return_counterpart_updates!
    notify_removed_shared_return_counterparts!

    mirrored_shared_return_transactions.each do |cash_transaction|
      Logic::SharedReturnStructureUpdateMessageService.new(transaction: cash_transaction).call
    end
  end

  def capture_shared_return_counterpart_destroy_notifications!
    @shared_return_counterpart_destroy_notifications = mirrored_shared_return_transactions.filter_map do |cash_transaction|
      counterpart_transaction = cash_transaction.counterpart_shared_return_transaction
      next if counterpart_transaction.blank?

      {
        transaction: cash_transaction,
        counterpart_transaction:
      }
    end
  end

  def notify_removed_shared_return_counterparts!
    notifications = @shared_return_counterpart_destroy_notifications || []
    return if notifications.empty?

    current_shared_return_ids = mirrored_shared_return_transactions.map(&:id)
    notifications.each do |notification|
      next if current_shared_return_ids.include?(notification[:transaction].id)

      Logic::SharedReturnDestroyMessageService.new(**notification).call
    end
  end

  def mirrored_shared_return_transactions
    @card_transaction.entity_transactions
                     .includes(exchanges: :cash_transaction)
                     .flat_map(&:exchanges)
                     .filter_map(&:cash_transaction)
                     .select(&:shared_return_flow?)
                     .uniq(&:id)
  end

  def handle_chain_finish_without_save
    set_return_to
    redirect_to chain_index_destination(current_chain_record_ids), status: :see_other
  end

  def chain_continuation_destination(record_ids)
    options = {
      chain_mode: current_chain_context[:mode],
      chain_record_ids: record_ids,
      continue_chain: "1",
      return_to: @return_to
    }

    if current_chain_context[:mode] == "duplicate"
      duplicate_card_transaction_path(@card_transaction, **options)
    else
      new_card_transaction_path(user_card_id: @card_transaction.user_card_id, **options)
    end
  end

  def chain_index_destination(record_ids)
    card_transactions = current_context.card_transactions.includes(:card_installments).where(id: record_ids)
    installment_ids = card_transactions.flat_map { |transaction| transaction.card_installments.map(&:id) }.uniq
    active_month_years = card_transactions.flat_map do |transaction|
      transaction.card_installments.map { |installment| Date.new(installment.year, installment.month).strftime("%Y%m").to_i }
    end.uniq
    return @return_to if installment_ids.empty?

    destination = card_transactions_path(
      user_card_id: @card_transaction.user_card_id,
      active_month_years: active_month_years.to_json,
      default_year: active_month_years.max.to_s.first(4).to_i,
      card_transaction: { card_installment_ids: installment_ids }
    )

    card_navigation_destination(destination)
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
    raw_ids = Array(params[:chain_record_ids]).compact_blank.map(&:to_s)
    return [] if raw_ids.size > Navigation::State::MAX_VALUES
    return [] unless raw_ids.all? { |id| id.match?(/\A[1-9]\d*\z/) }

    ids = raw_ids.map(&:to_i).uniq
    owned_ids = current_context.card_transactions.where(id: ids).ids

    owned_ids.sort == ids.sort ? ids : []
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

  def chain_workflow?
    current_chain_record_ids.any? || params[:chain_mode].present?
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
        exchange_bound_type
        month_year
        force_mobile
        sort
        direction
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
        :id, :entity_id, :is_payer, :price, :price_to_be_returned, :loan_return_percentage, :_destroy,
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

  def prune_exchange_entity_transactions_without_exchanges!
    return unless duplicate_cleanup_context?

    @card_transaction.entity_transactions.each do |entity_transaction|
      next if entity_transaction.marked_for_destruction?
      next if entity_transaction.price_to_be_returned.to_i.zero?
      next if entity_transaction.exchanges.reject(&:marked_for_destruction?).present?

      entity_transaction.mark_for_destruction
    end
  end

  def duplicate_cleanup_context?
    current_chain_context[:mode] == "duplicate" || @card_transaction.duplicate
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
