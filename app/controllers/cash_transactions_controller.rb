# frozen_string_literal: true

class CashTransactionsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include TabsConcern

  before_action :set_cash_transaction, only: %i[show edit update destroy fix_exchange_projection]
  before_action :ensure_submitted_context_matches_current_context!, only: %i[create update]
  before_action :set_cash_tabs

  def index
    build_index_context(current_context.cash_installments)

    respond_to do |format|
      format.html { render Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def month_year
    mobile = search_cash_transaction_params[:force_mobile] || @mobile
    month_year = search_cash_transaction_params[:month_year]

    cash_installments, budgets = Logic::CashTransactions.find_by_ref_month_year(current_context, cash_transaction_params, search_cash_transaction_params)

    render Views::CashTransactions::MonthYear.new(
      mobile:,
      month_year:,
      cash_installments:,
      budgets:,
      index_context: month_year_index_context(mobile)
    )
  end

  def show
    render Views::CashTransactions::Show.new(cash_transaction: @cash_transaction)
  end

  def new
    user_bank_account_id = params[:user_bank_account_id] || current_user.user_bank_accounts.active.first&.id
    @cash_transaction = current_context.cash_transactions.new(user: current_user, user_bank_account_id:, date: Time.zone.now)
    handle_params
    @chain_context = current_chain_context(mode: "create")

    respond_to do |format|
      format.html { render Views::CashTransactions::New.new(current_user:, cash_transaction: @cash_transaction, chain_context: @chain_context) }
      format.turbo_stream
    end
  end

  def edit
    @cash_transaction = current_context.cash_transactions
                                       .includes(
                                         :cash_installments,
                                         :categories,
                                         category_transactions: :category,
                                         entity_transactions: %i[entity exchanges]
                                       )
                                       .find(params[:id])
    handle_params

    respond_to do |format|
      format.html { render Views::CashTransactions::Edit.new(current_user:, cash_transaction: @cash_transaction) }
      format.turbo_stream
    end
  end

  def create
    @cash_transaction = current_context.cash_transactions.new(assignable_cash_transaction_params.merge(user: current_user, imported: false))
    apply_submitted_exchange_paid_states!
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id

    if finish_chain_without_save_requested?
      handle_chain_finish_without_save
      return
    end

    handle_save
  end

  def update
    @shared_paid_state_notifications = pending_shared_paid_state_notifications
    @exchange_projection_notification_required = exchange_projection_notification_required?
    @shared_return_counterpart_notification_required = shared_return_counterpart_notification_required?
    @cash_transaction.edit_phase = true if submitted_cash_installment_attributes.present?
    @cash_transaction.assign_attributes(assignable_cash_transaction_params.merge(imported: false))
    apply_submitted_exchange_paid_states!
    @cash_transaction.historical_correction_confirmation = cash_transaction_params[:historical_correction_confirmation]
    @cash_transaction.build_month_year if @cash_transaction.user_bank_account_id
    @cash_transaction.update_installments if params[:commit] == "Update"

    handle_save
  end

  def destroy
    @cash_transaction.historical_correction_confirmation = params[:historical_correction_confirmation]
    @user_bank_account = @cash_transaction.user_bank_account
    @cash_transaction.update_columns(date: @cash_transaction.cash_installments.order(:date).first.date)
    destroyed = @cash_transaction.destroy

    if destroyed
      mark_source_message_applied
      index
    end

    respond_to do |format|
      format.turbo_stream do
        render :destroy, status: destroyed ? :ok : :unprocessable_content
      end
    end
  end

  def duplicate
    @cash_transaction = build_duplicate_cash_transaction(params[:id])
    @chain_context = current_chain_context(mode: "duplicate")

    render Views::CashTransactions::New.new(current_user:, cash_transaction: @cash_transaction, chain_context: @chain_context)
  end

  def report_payment_failure
    @cash_transaction = current_context.cash_transactions.includes(:cash_installments, :categories).find(params[:id])
    return handle_payment_failure_unavailable unless @cash_transaction.return_failure_reportable?

    min_date = failed_return_recalculation_start
    @cash_transaction.report_payment_failure!
    recalculate_balances_from(min_date)

    render_payment_failure_success
  end

  def fix_exchange_projection
    unless exchange_projection_fixable?
      return redirect_to cash_transaction_path(@cash_transaction),
                         alert: I18n.t("cash_transactions.exchange_projection.unavailable")
    end

    min_date = @cash_transaction.date
    repair_exchange_projection!
    recalculate_balances_from([ min_date, @cash_transaction.date ].compact.min)

    redirect_to cash_transaction_path(@cash_transaction), notice: I18n.t("cash_transactions.exchange_projection.fixed")
  rescue StandardError => e
    redirect_to cash_transaction_path(@cash_transaction), alert: e.message
  end

  def add_to_subscription # rubocop:disable Metrics/AbcSize
    @subscription = current_context.subscriptions.find_by(id: params[:subscription_id])
    return render_bulk_subscription_failure(I18n.t("bulk_actions.invalid_subscription")) if @subscription.blank?

    transactions = selected_cash_transactions_for_bulk_subscription
    return render_bulk_subscription_failure(I18n.t("bulk_actions.empty_selection")) if transactions.empty?

    failed_transaction = nil

    ActiveRecord::Base.transaction do
      @subscription.attach_transactions!(transactions)
    rescue ActiveRecord::RecordInvalid => e
      failed_transaction = e.record
      raise ActiveRecord::Rollback
    end

    return render_bulk_subscription_failure(notification_model_or_history_lock(failed_transaction, :not_updateda, CashTransaction)) if failed_transaction.present?

    build_index_context_from_selection? || build_index_context(current_context.cash_installments)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: I18n.t("notification.added_to_subscription") })
        ]
      end
    end
  end

  def handle_params
    assign_message_context
    handle_category_params
    handle_entity_params

    if effective_cash_transaction_params[:cash_installments_attributes].present?
      @cash_transaction.edit_phase = true if @cash_transaction.persisted?

      assign_cash_installments_from_effective_params
      assign_cash_transaction_fields_from_effective_params
    elsif @cash_transaction.new_record?
      @cash_transaction.build_month_year
    end
  end

  def handle_category_params
    return if effective_cash_transaction_params[:category_id].nil?

    new_category_id = effective_cash_transaction_params[:category_id].to_i
    current_category_ids = @cash_transaction.category_transactions.reject(&:marked_for_destruction?).map(&:category_id).sort
    return if current_category_ids == [ new_category_id ]

    if replaying_reference_transaction? || (@cash_transaction.persisted? && current_category_ids.one?)
      @cash_transaction.category_transactions.each(&:mark_for_destruction)
    end

    @cash_transaction.category_transactions.build(category_id: new_category_id)
  end

  def handle_entity_params
    current_entities = @cash_transaction.entity_transactions.pluck(:entity_id)

    entity_id = effective_cash_transaction_params[:entity_id]&.to_i
    @cash_transaction.entity_transactions.build(entity_id:) if entity_id && current_entities.exclude?(entity_id)

    attributes = effective_cash_transaction_params[:entity_transactions_attributes]
    return if attributes.blank?

    submitted = normalized_nested_attributes(attributes)
    new_entities = submitted.pluck(:entity_id).map(&:to_i)

    if current_entities.one? && current_entities == new_entities
      synchronize_single_entity_transaction(current_entities, submitted)
    else
      @cash_transaction.entity_transactions.each(&:mark_for_destruction)
      @cash_transaction.entity_transactions_attributes = sanitize_entity_transaction_attributes(submitted)
    end
  end

  def synchronize_entity_transaction_exchanges(entity_transaction, exchanges_attributes)
    exchanges_attributes = normalized_nested_attributes(exchanges_attributes)
    existing_exchanges_by_number = entity_transaction.exchanges.index_by(&:number)

    entity_transaction.exchanges.each do |exchange|
      new_attributes = exchanges_attributes.find { |attrs| attrs[:number].to_i == exchange.number }

      if new_attributes.present?
        assign_exchange_attributes(exchange, new_attributes)
      else
        exchange.mark_for_destruction
      end
    end

    exchanges_attributes.each do |exchange_attributes|
      next if existing_exchanges_by_number.key?(exchange_attributes[:number].to_i)

      exchange = entity_transaction.exchanges.build(exchange_attributes.except(:paid))
      exchange.replay_paid_state = cast_exchange_paid_state(exchange_attributes[:paid])
    end
  end

  def assign_exchange_attributes(exchange, attributes)
    exchange.assign_attributes(attributes.except(:paid))
    exchange.replay_paid_state = cast_exchange_paid_state(attributes[:paid])
  end

  def cast_exchange_paid_state(value)
    return nil if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def synchronize_single_entity_transaction(current_entities, submitted)
    entity_transaction = @cash_transaction.entity_transactions.find do |record|
      current_entities.include?(record.entity_id)
    end
    submitted_entity_transaction = submitted.find do |record|
      record[:entity_id].to_i == entity_transaction&.entity_id
    end

    return if entity_transaction.blank? || submitted_entity_transaction.blank?

    entity_transaction.assign_attributes(submitted_entity_transaction.except(:exchanges_attributes))
    synchronize_entity_transaction_exchanges(entity_transaction, submitted_entity_transaction[:exchanges_attributes])
  end

  def replaying_reference_transaction?
    effective_cash_transaction_params[:reference_transactable_id].present?
  end

  def assign_cash_installments_from_effective_params
    attributes = normalized_nested_attributes(effective_cash_transaction_params[:cash_installments_attributes])

    if @cash_transaction.persisted?
      synchronize_cash_installments(attributes)
    else
      @cash_transaction.association(:cash_installments).target = []
      @cash_transaction.cash_installments_attributes = attributes
    end
  end

  def assign_cash_transaction_fields_from_effective_params
    @cash_transaction.description = effective_cash_transaction_params[:description]
    @cash_transaction.price = effective_cash_transaction_params[:price]
    @cash_transaction.date = effective_cash_transaction_params[:date]
    @cash_transaction.month = effective_cash_transaction_params[:month]
    @cash_transaction.year = effective_cash_transaction_params[:year]
  end

  def synchronize_cash_installments(attributes)
    attributes = Array(attributes).map(&:with_indifferent_access)
    existing_installments = @cash_transaction.cash_installments.to_a

    existing_installments.each do |installment|
      new_attributes = matching_cash_installment_attributes(attributes, installment)

      if new_attributes.present?
        installment.assign_attributes(new_attributes)
      else
        installment.mark_for_destruction
      end
    end

    attributes.each do |installment_attributes|
      next if matching_existing_cash_installment(existing_installments, installment_attributes).present?

      @cash_transaction.cash_installments.build(installment_attributes)
    end
  end

  def matching_cash_installment_attributes(attributes, installment)
    attributes.find do |attrs|
      installment_matches_attributes?(installment, attrs)
    end
  end

  def matching_existing_cash_installment(existing_installments, installment_attributes)
    existing_installments.find do |installment|
      installment_matches_attributes?(installment, installment_attributes)
    end
  end

  def installment_matches_attributes?(installment, attributes)
    (attributes[:id].present? && attributes[:id].to_i == installment.id) || attributes[:number].to_i == installment.number
  end

  def assign_message_context
    @cash_transaction.assign_attributes(
      message_context_attributes
    )

    counterpart_reference = canonical_message_reference_transactable
    if counterpart_reference.present?
      @cash_transaction.assign_attributes(
        reference_transactable_type: counterpart_reference.class.name,
        reference_transactable_id: counterpart_reference.id
      )

      return
    end

    return if @cash_transaction.persisted? && @cash_transaction.reference_transactable.present?

    @cash_transaction.assign_attributes(
      effective_cash_transaction_params.slice(
        :reference_transactable_type,
        :reference_transactable_id
      )
    )
  end

  def message_context_attributes
    attributes = effective_cash_transaction_params.slice(:source_message_id, :friend_notification_intent)
    attributes[:friend_notification_intent] = effective_message_intent if attributes[:friend_notification_intent].blank? && source_message.present?

    return attributes if read_request?
    return attributes if effective_category_names.include?("EXCHANGE")

    attributes.except(:friend_notification_intent)
  end

  def assignable_cash_transaction_params
    params = sanitized_cash_transaction_params_for_assignment(
      deduplicated_cash_transaction_params(effective_cash_transaction_params).except(:source_message_id)
    )
    params = strip_non_exchange_friend_notification_intent(params)
    counterpart_reference = canonical_message_reference_transactable
    if counterpart_reference.present?
      return params.merge(reference_transactable_type: counterpart_reference.class.name,
                          reference_transactable_id: counterpart_reference.id)
    end
    return params unless preserve_existing_reference_transactable?

    params.except(:reference_transactable_type, :reference_transactable_id)
  end

  def strip_non_exchange_friend_notification_intent(params)
    return params if effective_category_names.include?("EXCHANGE")

    params.except(:friend_notification_intent)
  end

  def preserve_existing_reference_transactable?
    @cash_transaction&.persisted? &&
      @cash_transaction.reference_transactable.present? &&
      source_message.present?
  end

  def canonical_message_reference_transactable
    return if source_message.blank?
    return sender_shared_return_reference_from_source_message if target_requires_sender_shared_return_reference?
    return existing_exchange_return_parent_reference if existing_exchange_return_parent_reference.present?
    return unless @cash_transaction&.persisted?
    return unless @cash_transaction.respond_to?(:borrow_return?) && @cash_transaction.respond_to?(:exchange_return?)
    return unless @cash_transaction.borrow_return? || @cash_transaction.exchange_return?

    sender_shared_return_reference_from_source_message ||
      (@cash_transaction.counterpart_shared_return_transaction if @cash_transaction.respond_to?(:counterpart_shared_return_transaction))
  end

  def sender_shared_return_reference_from_source_message
    reference_transaction = source_message.reference_transactable
    return reference_transaction if reference_transaction.is_a?(CashTransaction) && reference_transaction.exchange_return?
    return unless reference_transaction.is_a?(CardTransaction) || reference_transaction.is_a?(CashTransaction)

    reference_transaction.entity_transactions
                         .includes(exchanges: :cash_transaction)
                         .flat_map(&:exchanges)
                         .select(&:monetary?)
                         .map(&:cash_transaction)
                         .compact
                         .find(&:exchange_return?)
  end

  def existing_exchange_return_parent_reference
    return unless @cash_transaction&.persisted?
    return unless @cash_transaction.respond_to?(:exchange_return?) && @cash_transaction.exchange_return?
    return if @cash_transaction.reference_transactable.blank?
    return if @cash_transaction.reference_transactable == @cash_transaction

    @cash_transaction.reference_transactable
  end

  def target_requires_sender_shared_return_reference?
    category_names = effective_category_names
    return true if category_names.include?("BORROW RETURN")

    category_names.include?("EXCHANGE") && effective_message_intent == "loan"
  end

  def effective_category_names
    category_ids = effective_category_ids
    return @cash_transaction.categories.pluck(:category_name) if category_ids.blank? && @cash_transaction&.persisted?

    current_user.categories.where(id: category_ids).pluck(:category_name)
  end

  def effective_category_ids
    ids = Array(effective_cash_transaction_params[:category_id])
    ids += normalized_nested_attributes(effective_cash_transaction_params[:category_transactions_attributes]).filter_map do |attrs|
      next if ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])

      attrs[:category_id]
    end

    ids.compact_blank.map(&:to_i).uniq
  end

  def effective_message_intent
    effective_cash_transaction_params[:friend_notification_intent].presence ||
      source_message&.replay_payload&.fetch("intent", nil).presence ||
      source_message&.reference_transactable.try(:effective_friend_notification_intent)
  end

  def source_message_id
    @cash_transaction&.source_message_id.presence || cash_transaction_params[:source_message_id].presence || params[:message_id].presence
  end

  def source_message
    return if source_message_id.blank?

    @source_message ||= current_user.received_messages
                                    .joins(:conversation)
                                    .where(conversations: { scenario_key: current_context.scenario_key })
                                    .find_by(id: source_message_id)
  end

  def mark_source_message_applied
    source_message&.update!(applied_at: Time.current)
  end

  def handle_save
    assign_message_context

    return render_update_form if params[:commit] == "Update"

    saved = @cash_transaction.save
    normalize_failed_cash_transaction_save!
    @chain_context = current_chain_context

    handle_successful_save if saved

    respond_to do |format|
      format.turbo_stream do
        render action_name, status: saved ? :ok : :unprocessable_content
      end
    end
  end

  def ensure_submitted_context_matches_current_context!
    return if submitted_context_id.blank? || submitted_context_id == current_context.id

    respond_to do |format|
      format.html { redirect_to cash_transactions_path, alert: t("contexts.switch.stale_transaction_form"), status: :see_other }
      format.turbo_stream { redirect_to cash_transactions_path, alert: t("contexts.switch.stale_transaction_form"), status: :see_other }
    end
  end

  def submitted_context_id
    params.dig(:cash_transaction, :context_id).presence&.to_i
  end

  def normalize_failed_cash_transaction_save!
    nested_error_messages = collect_nested_cash_transaction_error_messages
    return if @cash_transaction.errors.empty? && nested_error_messages.empty?

    nested_error_messages.each do |message|
      @cash_transaction.errors.add(:base, message) unless @cash_transaction.errors[:base].include?(message)
    end
    @cash_transaction.errors.add(:base, :invalid) if @cash_transaction.errors.details[:base].exclude?(error: :invalid)
  end

  def collect_nested_cash_transaction_error_messages
    nested_records = @cash_transaction.cash_installments.to_a +
                     @cash_transaction.entity_transactions.to_a +
                     @cash_transaction.entity_transactions.flat_map(&:exchanges)

    nested_records.flat_map { |record| record.errors.full_messages }.compact_blank.uniq
  end

  def pending_shared_paid_state_notifications
    return [] unless @cash_transaction.shared_return_flow?

    submitted_cash_installment_attributes.filter_map do |installment_attributes|
      installment_attributes = installment_attributes.with_indifferent_access
      installment_id = installment_attributes[:id].presence&.to_i
      next if installment_id.blank?

      installment = @cash_transaction.cash_installments.find { |record| record.id == installment_id }
      next if installment.blank?

      submitted_paid = ActiveModel::Type::Boolean.new.cast(installment_attributes[:paid])
      next if installment.paid == submitted_paid

      {
        installment_id: installment.id,
        installment_number: installment.number,
        paid: submitted_paid
      }
    end
  end

  def submitted_cash_installment_attributes
    normalized_nested_attributes(effective_cash_transaction_params[:cash_installments_attributes])
  end

  def sync_shared_paid_state_messages_from_form!
    return if @shared_paid_state_notifications.blank?

    counterpart_user = @cash_transaction.reference_transactable&.user || @cash_transaction.entities.that_are_users.first&.entity_user
    return if counterpart_user.blank?

    conversation = Conversation.find_or_create_assistant_between!(current_user, counterpart_user, scenario_key: @cash_transaction.context.scenario_key)

    @shared_paid_state_notifications.each do |notification|
      create_shared_paid_state_message(conversation:, counterpart_user:, notification:)
    end
  end

  def render_update_form
    @chain_context = current_chain_context

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          @cash_transaction,
          Views::CashTransactions::Form.new(current_user: @current_user, cash_transaction: @cash_transaction, chain_context: @chain_context)
        ), status: :ok
      end
    end
  end

  def handle_successful_save
    if @cash_transaction.edit_phase && @cash_transaction.exchange_return?
      @cash_transaction.sync_exchange_projection_back_to_source!
      notify_exchange_projection_counterpart_update! if @exchange_projection_notification_required && source_message.blank?
    end

    notify_shared_return_counterpart_update! if @shared_return_counterpart_notification_required && source_message.blank?

    sync_shared_paid_state_messages_from_form!
    mark_source_message_applied
    handle_chain_save_success
  end

  def handle_chain_save_success
    created_record_ids = updated_chain_record_ids(@cash_transaction.id)

    if continue_chain?
      @chain_context = current_chain_context(record_ids: created_record_ids, checked: true)
      @next_cash_transaction = next_cash_transaction_for_chain
      return
    end

    index
    ensure_index_context!
    @index_context[:user_bank_account_id] = []
    apply_chain_index_context(record_ids: created_record_ids)
  end

  def handle_chain_finish_without_save
    @finished_chain_without_save = true
    index
    ensure_index_context!
    @index_context[:user_bank_account_id] = []
    apply_chain_index_context(record_ids: current_chain_record_ids)

    respond_to do |format|
      format.turbo_stream { render :create, status: :ok }
    end
  end

  def active_month_years_for(cash_transaction)
    cash_transaction.cash_installments.map { |installment| Date.new(installment.year, installment.month).strftime("%Y%m").to_i }.uniq
  end

  def apply_chain_index_context(record_ids:)
    cash_transactions = current_context.cash_transactions.includes(:cash_installments).where(id: record_ids)
    installment_ids = cash_transactions.flat_map { |transaction| transaction.cash_installments.pluck(:id) }.uniq
    active_month_years = cash_transactions.flat_map { |transaction| active_month_years_for(transaction) }.uniq

    @index_context[:cash_installment_ids] = installment_ids
    @index_context[:active_month_years] = active_month_years.presence || @index_context[:active_month_years]
    @index_context[:default_year] = active_month_years.max.to_s.first(4).to_i if active_month_years.present?
  end

  def ensure_index_context!
    return if @index_context.present? && @index_context[:current_user].present?

    build_index_context(current_context.cash_installments)
  end

  def next_cash_transaction_for_chain
    if current_chain_context[:mode] == "duplicate"
      build_duplicate_cash_transaction(@cash_transaction.id)
    else
      current_context.cash_transactions.new(
        user: current_user,
        user_bank_account_id: current_user.user_bank_accounts.active.first&.id,
        date: Time.zone.now
      )
    end
  end

  def build_duplicate_cash_transaction(id)
    CashTransaction.duplicate(id).tap do |cash_transaction|
      cash_transaction.price = 0
      cash_transaction.cash_installments.each { |installment| installment.price = 0 }
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

  def create_shared_paid_state_message(conversation:, counterpart_user:, notification:)
    installment = @cash_transaction.cash_installments.find_by(id: notification[:installment_id])
    return if installment.blank?

    headers = build_shared_paid_state_headers(counterpart_user:, installment:, notification:).to_json
    return if Message.exists?(conversation:, body: "notification:paid_state", headers:)

    conversation.messages.create!(user: current_user, reference_transactable: @cash_transaction, body: "notification:paid_state", headers:)
  end

  def build_shared_paid_state_headers(counterpart_user:, installment:, notification:)
    {
      version: "message_paid_state_v1",
      event: {
        action: notification[:paid] ? "paid" : "unpaid",
        receiver_first_name: counterpart_user.first_name,
        transaction_type: "CashTransaction",
        details: {
          transaction_label: CashTransaction.model_name.human,
          description: @cash_transaction.description,
          installment_number: notification[:installment_number],
          installments_count: @cash_transaction.cash_installments_count,
          date: installment.date&.iso8601,
          paid: notification[:paid]
        }
      }
    }
  end

  def exchange_projection_notification_required?
    return false unless @cash_transaction.exchange_return?

    exchange_projection_notification_required_for_submitted_installments?
  end

  def shared_return_counterpart_notification_required?
    return false unless @cash_transaction.borrow_return?
    return false unless @cash_transaction.shared_return_flow?

    exchange_projection_notification_required_for_submitted_installments?
  end

  def exchange_projection_notification_required_for_submitted_installments?
    return false if submitted_cash_installment_attributes.blank?

    submitted_cash_installment_attributes.any? do |installment_attributes|
      installment_attributes = installment_attributes.with_indifferent_access

      installment_attributes[:_destroy].to_s == "true" ||
        installment_attributes[:id].blank? ||
        exchange_projection_installment_fields_changed?(installment_attributes)
    end
  end

  def exchange_projection_installment_fields_changed?(installment_attributes)
    installment = @cash_transaction.cash_installments.find { |record| record.id == installment_attributes[:id].to_i }
    return false if installment.blank?

    {
      number: installment.number,
      date: installment.date&.iso8601,
      month: installment.month,
      year: installment.year,
      price: installment.price
    }.any? do |key, previous_value|
      submitted_value = installment_attributes[key]
      next false if submitted_value.blank?

      normalized_submitted_value =
        case key
        when :number, :month, :year, :price
          submitted_value.to_i
        when :date
          Time.zone.parse(submitted_value)&.iso8601
        end

      normalized_submitted_value != previous_value
    rescue ArgumentError
      true
    end
  end

  def notify_exchange_projection_counterpart_update!
    source_transactable = @cash_transaction.exchanges.includes(entity_transaction: :transactable).first&.entity_transaction&.transactable
    return if source_transactable.blank?
    return unless source_transactable.respond_to?(:notify_friends, true)

    source_transactable.send(:notify_friends, :update)
  end

  def notify_shared_return_counterpart_update!
    Logic::SharedReturnStructureUpdateMessageService.new(transaction: @cash_transaction).call
  end

  def build_index_context(cash_installments)
    @index_context = IndexState::CashTransactions.new(
      current_user:,
      current_context:,
      params:,
      cash_installments:,
      transaction_filters: cash_transaction_params,
      search_filters: search_cash_transaction_params
    ).to_h
  end

  private

  def set_cash_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :pix)
  end

  def build_index_context_from_selection?
    return false if params[:index_context_json].blank?

    @index_context = IndexState::CashTransactions.new(
      current_user:,
      current_context:,
      params:,
      cash_installments: current_context.cash_installments,
      transaction_filters: cash_transaction_params,
      search_filters: search_cash_transaction_params,
      selection_context: JSON.parse(params[:index_context_json])
    ).to_h
    @mobile = @index_context[:force_mobile]

    true
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_cash_transaction
    @cash_transaction = current_context.cash_transactions.find(params[:id])
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
        from_installments_number
        to_installments_number
        exchange_bound_type
        from_date
        to_date
        paid
        pending
        paid_state
        month_year
        skip_budgets
        force_mobile
        sort
        direction
      ]
    )
  end

  # Only allow a list of trusted parameters through.
  def cash_transaction_params
    return {} if params[:cash_transaction].blank?

    params.require(:cash_transaction).permit(
      %i[
        id description comment date month year price paid user_id user_bank_account_id
        reference_transactable_type reference_transactable_id category_id entity_id subscription_id
        friend_notification_intent source_message_id historical_correction_confirmation
      ],
      user_bank_account_id: [], category_id: [], entity_id: [], cash_installment_ids: [],
      category_transactions_attributes: %i[id category_id _destroy],
      cash_installments_attributes: %i[id number date month year price paid _destroy],
      piggy_bank_attributes: %i[id return_cash_transaction_id return_date return_price _destroy],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price, :price_to_be_returned, :loan_return_percentage, :_destroy,
        { exchanges_attributes: %i[id number exchange_type bound_type price date month year paid _destroy] }
      ]
    )
  end

  def effective_cash_transaction_params
    return @effective_cash_transaction_params if defined?(@effective_cash_transaction_params)

    @effective_cash_transaction_params =
      if should_hydrate_from_source_message?
        replay_cash_transaction_params_from_source
      else
        cash_transaction_params.to_h.with_indifferent_access
      end
  end

  def should_hydrate_from_source_message?
    source_message.present? && read_request? && cash_transaction_params.keys == [ "source_message_id" ]
  end

  def read_request?
    request.get? || request.head?
  end

  def replay_cash_transaction_params_from_source
    payload = source_message&.replay_payload || {}

    {
      description: payload["description"],
      price: payload["price"],
      date: payload["date"],
      month: payload["month"],
      year: payload["year"],
      category_id: Array(payload["category_ids"]).first,
      entity_id: Array(payload["entity_ids"]).first,
      friend_notification_intent: payload["intent"],
      reference_transactable_type: payload["type"],
      reference_transactable_id: payload["id"],
      source_message_id: source_message.id,
      cash_installments_attributes: replay_cash_installments_attributes_from_source(payload),
      entity_transactions_attributes: payload["entity_transactions_attributes"]
    }.compact_blank.with_indifferent_access
  end

  def replay_cash_installments_attributes_from_source(payload)
    attributes = Array(payload["cash_installments_attributes"]).map(&:with_indifferent_access)
    return attributes unless @cash_transaction&.persisted?

    existing_installments_by_number = @cash_transaction.cash_installments.index_by(&:number)

    attributes.map do |attrs|
      existing_installment = existing_installments_by_number[attrs[:number].to_i]

      attrs.merge(id: existing_installment&.id).compact
    end
  end

  def month_year_index_context(mobile) # rubocop:disable Metrics/AbcSize
    sort, direction = IndexState::CashTransactions.resolve_sort(
      sort: search_cash_transaction_params[:sort],
      direction: search_cash_transaction_params[:direction]
    )

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
      exchange_bound_type: search_cash_transaction_params[:exchange_bound_type],
      from_installments_number: search_cash_transaction_params[:from_installments_number],
      to_installments_number: search_cash_transaction_params[:to_installments_number],
      from_date: search_cash_transaction_params[:from_date],
      to_date: search_cash_transaction_params[:to_date],
      paid: month_year_paid_filters[:paid],
      pending: month_year_paid_filters[:pending],
      paid_state: month_year_paid_filters[:paid_state],
      skip_budgets: search_cash_transaction_params[:skip_budgets],
      sort:,
      direction:,
      force_mobile: mobile
    }
  end

  def month_year_paid_filters
    @month_year_paid_filters ||= IndexState::CashTransactions.resolve_paid_filters(
      paid_state: search_cash_transaction_params[:paid_state],
      paid: search_cash_transaction_params[:paid],
      pending: search_cash_transaction_params[:pending]
    )
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
    attributes.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }
  end

  def deduplicated_cash_transaction_params(attributes)
    attributes.merge(
      category_transactions_attributes: deduplicate_nested_attributes(attributes[:category_transactions_attributes], key: :category_id),
      entity_transactions_attributes: deduplicate_nested_attributes(attributes[:entity_transactions_attributes], key: :entity_id)
    )
  end

  def sanitized_cash_transaction_params_for_assignment(attributes)
    sanitized = attributes.deep_dup
    sanitized[:entity_transactions_attributes] = sanitize_entity_transaction_attributes(sanitized[:entity_transactions_attributes])

    sanitized
  end

  def sanitize_entity_transaction_attributes(attributes)
    normalized_nested_attributes(attributes).map do |entity_transaction_attributes|
      entity_transaction_attributes = entity_transaction_attributes.with_indifferent_access
      exchanges_attributes = normalized_nested_attributes(entity_transaction_attributes[:exchanges_attributes]).map do |exchange_attributes|
        exchange_attributes.with_indifferent_access.except(:paid)
      end

      entity_transaction_attributes.merge(exchanges_attributes:)
    end
  end

  def apply_submitted_exchange_paid_states!
    submitted_entity_transactions = normalized_nested_attributes(effective_cash_transaction_params[:entity_transactions_attributes])

    submitted_entity_transactions.each do |entity_transaction_attributes|
      entity_transaction = find_submitted_entity_transaction(entity_transaction_attributes)
      next if entity_transaction.blank?

      normalized_nested_attributes(entity_transaction_attributes[:exchanges_attributes]).each do |exchange_attributes|
        exchange = find_submitted_exchange(entity_transaction, exchange_attributes)
        next if exchange.blank?

        exchange.replay_paid_state = cast_exchange_paid_state(exchange_attributes[:paid])
      end
    end
  end

  def find_submitted_entity_transaction(attributes)
    attributes = attributes.with_indifferent_access
    submitted_id = attributes[:id].presence&.to_i
    return @cash_transaction.entity_transactions.find { |record| record.id == submitted_id } if submitted_id.present?

    submitted_entity_id = attributes[:entity_id].presence&.to_i
    return if submitted_entity_id.blank?

    @cash_transaction.entity_transactions.find { |record| record.entity_id == submitted_entity_id }
  end

  def find_submitted_exchange(entity_transaction, attributes)
    attributes = attributes.with_indifferent_access
    submitted_id = attributes[:id].presence&.to_i
    return entity_transaction.exchanges.find { |record| record.id == submitted_id } if submitted_id.present?

    submitted_number = attributes[:number].presence&.to_i
    return if submitted_number.blank?

    entity_transaction.exchanges.find { |record| record.number == submitted_number }
  end

  def deduplicate_nested_attributes(attributes, key:)
    seen_values = {}

    normalized_nested_attributes(attributes).filter_map do |entry|
      next entry if entry.blank?
      next entry if ActiveModel::Type::Boolean.new.cast(entry[:_destroy])

      nested_value = entry[key].presence
      next entry if nested_value.blank?
      next if seen_values[nested_value.to_s]

      seen_values[nested_value.to_s] = true
      entry
    end
  end

  def selected_cash_transactions_for_bulk_subscription
    current_context.cash_transactions.where(id: Array(params[:ids].to_s.split(",")).compact_blank).to_a
  end

  def render_bulk_subscription_failure(alert_message)
    build_index_context_from_selection? || build_index_context(current_context.cash_installments)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: alert_message })
        ], status: :unprocessable_content
      end
    end
  end

  def handle_payment_failure_unavailable
    build_index_context_from_selection? || build_index_context(current_context.cash_installments)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: I18n.t("cash_transactions.payment_failure.unavailable") })
        ], status: :unprocessable_content
      end
    end
  end

  def failed_return_recalculation_start
    @cash_transaction.cash_installments.where(paid: false).minimum(:date) || @cash_transaction.date
  end

  def repair_exchange_projection!
    ActiveRecord::Base.transaction do
      fix_stale_card_bound_projection_buckets! if stale_card_bound_projection_bucket_fixable?
      move_out_of_bucket_projection_exchanges!
      sync_current_projection_exchanges!
      @duplicate_card_bound_projection_transactions = nil
      @cash_transaction = merge_duplicate_card_bound_projection_transactions!
      sync_current_projection_exchanges!
    end
  end

  def move_out_of_bucket_projection_exchanges!
    @out_of_bucket_card_bound_projection_exchanges = nil
    @incoming_wrong_owner_card_bound_projection_exchanges = nil
    rehomed_projection_transactions = rehome_out_of_bucket_card_bound_projection_exchanges!
    @projection_exchanges = nil
    @cash_transaction.reload
    return unless projection_exchanges.empty? && rehomed_projection_transactions.present?

    @cash_transaction.destroy!
    @cash_transaction = rehomed_projection_transactions.first.reload
    @projection_exchanges = nil
  end

  def sync_current_projection_exchanges!
    @projection_exchanges = nil
    projection_exchanges.first&.send(:sync_projection_cash_transaction!, cash_transaction: @cash_transaction, exchanges: projection_exchanges)
    @cash_transaction.reload
  end

  def exchange_projection_fixable?
    @cash_transaction.exchange_return? &&
      projection_exchanges.present? &&
      (@cash_transaction.price != projection_exchanges.sum(&:price) ||
        stale_card_bound_projection_bucket_fixable? ||
        out_of_bucket_card_bound_projection_exchanges.present? ||
        incoming_wrong_owner_card_bound_projection_exchanges.present? ||
        duplicate_card_bound_projection_transactions.present?)
  end

  def projection_exchanges
    @projection_exchanges ||= @cash_transaction.exchanges.includes(entity_transaction: :entity).card_bound.monetary
  end

  def stale_card_bound_projection_bucket_fixable?
    stale_own_card_bound_projection_exchanges.present? || incoming_stale_card_bound_projection_exchanges.present?
  end

  def merge_duplicate_card_bound_projection_transactions!
    target = preferred_duplicate_card_bound_projection_transaction
    return @cash_transaction if target.blank?

    duplicate_card_bound_projection_transactions.where.not(id: target.id).find_each do |duplicate|
      duplicate.exchanges.update_all(cash_transaction_id: target.id, updated_at: Time.current)
      duplicate.destroy!
    end

    target.reload
  end

  def preferred_duplicate_card_bound_projection_transaction
    duplicate_card_bound_projection_transactions.max_by do |transaction|
      [
        transaction.user_card_id.present? ? 1 : 0,
        transaction.cash_installments.any? { |installment| !installment.paid? } ? 1 : 0,
        transaction.exchanges.size,
        transaction.cash_installments.any?(&:paid?) ? 1 : 0,
        transaction.updated_at.to_i,
        transaction.id
      ]
    end
  end

  def duplicate_card_bound_projection_transactions
    @duplicate_card_bound_projection_transactions ||= begin
      user_card_ids = projection_exchange_user_card_ids
      if user_card_ids.empty?
        current_context.cash_transactions.where(id: @cash_transaction.id)
      else
        duplicate_ids = current_context.cash_transactions
                                       .exchange_return
                                       .where(
                                         user_id: current_user.id,
                                         user_card_id: user_card_ids,
                                         cash_transaction_type: @cash_transaction.cash_transaction_type,
                                         description: @cash_transaction.description,
                                         month: @cash_transaction.month,
                                         year: @cash_transaction.year
                                       )
                                       .pluck(:id)
        current_context.cash_transactions.where(id: [ @cash_transaction.id, *duplicate_ids ].uniq)
                       .includes(:cash_installments, exchanges: { entity_transaction: :entity })
      end
    end
  end

  def fix_stale_card_bound_projection_buckets!
    (stale_own_card_bound_projection_exchanges + incoming_stale_card_bound_projection_exchanges).uniq.each do |exchange|
      source_installment = card_bound_projection_source_installment(exchange)
      next if source_installment.blank?

      exchange.update_columns(
        month: source_installment.month,
        year: source_installment.year,
        date: card_bound_projection_reference_date(exchange, source_installment),
        updated_at: Time.current
      )
    end
  end

  def rehome_out_of_bucket_card_bound_projection_exchanges!
    rehomed_projection_transactions = []
    (out_of_bucket_card_bound_projection_exchanges + incoming_wrong_owner_card_bound_projection_exchanges).uniq.each do |exchange|
      exchange.update_columns(cash_transaction_id: nil, updated_at: Time.current)
      exchange.reload
      exchange.send(:create_cash_transaction)
      exchange.save!
      rehomed_projection_transactions << exchange.reload.cash_transaction if exchange.cash_transaction.present?
    end
    rehomed_projection_transactions.uniq
  end

  def out_of_bucket_card_bound_projection_exchanges
    @out_of_bucket_card_bound_projection_exchanges ||= projection_exchanges.reject do |exchange|
      exchange.month == @cash_transaction.month && exchange.year == @cash_transaction.year
    end
  end

  def incoming_wrong_owner_card_bound_projection_exchanges
    @incoming_wrong_owner_card_bound_projection_exchanges ||= begin
      group_keys = projection_exchange_group_keys
      if group_keys.empty?
        []
      else
        Exchange.card_bound.monetary.joins(:cash_transaction)
                .where(cash_transactions: { context_id: current_context.id })
                .where.not(cash_transaction_id: @cash_transaction.id)
                .includes(entity_transaction: :entity)
                .select do |exchange|
                  incoming_wrong_owner_card_bound_projection_exchange?(exchange, group_keys)
                end
      end
    end
  end

  def incoming_wrong_owner_card_bound_projection_exchange?(exchange, group_keys)
    source_transaction = exchange.entity_transaction&.transactable
    return false unless source_transaction.is_a?(CardTransaction)
    return false unless group_keys.include?([ source_transaction.user_card_id, exchange.entity_transaction.entity_id ])
    return false unless exchange.month == @cash_transaction.month && exchange.year == @cash_transaction.year

    source_installment = card_bound_projection_source_installment(exchange)
    source_installment.present? && source_installment.month == @cash_transaction.month && source_installment.year == @cash_transaction.year
  end

  def projection_exchange_group_keys
    projection_exchanges.filter_map do |exchange|
      source_transaction = exchange.entity_transaction&.transactable
      [ source_transaction.user_card_id, exchange.entity_transaction.entity_id ] if source_transaction.is_a?(CardTransaction)
    end.uniq
  end

  def stale_own_card_bound_projection_exchanges
    @stale_own_card_bound_projection_exchanges ||= projection_exchanges.select do |exchange|
      stale_card_bound_projection_exchange?(exchange)
    end
  end

  def incoming_stale_card_bound_projection_exchanges
    @incoming_stale_card_bound_projection_exchanges ||= begin
      user_card_ids = projection_exchange_user_card_ids
      if user_card_ids.empty?
        []
      else
        Exchange.card_bound.monetary.joins(:cash_transaction)
                .where(cash_transactions: { context_id: current_context.id })
                .where.not(cash_transaction_id: @cash_transaction.id)
                .includes(entity_transaction: :entity)
                .select do |exchange|
                  incoming_stale_card_bound_projection_exchange?(exchange, user_card_ids)
                end
      end
    end
  end

  def incoming_stale_card_bound_projection_exchange?(exchange, user_card_ids)
    source_transaction = exchange.entity_transaction&.transactable
    return false unless source_transaction.is_a?(CardTransaction)
    return false unless user_card_ids.include?(source_transaction.user_card_id)

    source_installment = card_bound_projection_source_installment(exchange)
    return false if source_installment.blank?
    return false unless source_installment.month == @cash_transaction.month && source_installment.year == @cash_transaction.year

    stale_card_bound_projection_exchange?(exchange)
  end

  def stale_card_bound_projection_exchange?(exchange)
    source_installment = card_bound_projection_source_installment(exchange)
    return false if source_installment.blank?

    exchange.month != source_installment.month || exchange.year != source_installment.year
  end

  def projection_exchange_user_card_ids
    projection_exchanges.filter_map do |exchange|
      source_transaction = exchange.entity_transaction&.transactable
      source_transaction.user_card_id if source_transaction.is_a?(CardTransaction)
    end.uniq
  end

  def card_bound_projection_source_installment(exchange)
    source_transaction = exchange.entity_transaction&.transactable
    return unless source_transaction.is_a?(CardTransaction)

    source_transaction.card_installments.find_by(number: exchange.number)
  end

  def card_bound_projection_reference_date(exchange, source_installment)
    source_transaction = exchange.entity_transaction&.transactable
    reference = source_transaction.user_card.references.find_by(
      context: source_transaction.context,
      month: source_installment.month,
      year: source_installment.year
    )

    return reference.reference_date.end_of_day if reference.present?

    due_day = [ source_transaction.user_card.due_date_day, Time.days_in_month(source_installment.month, source_installment.year) ].min
    Time.zone.local(source_installment.year, source_installment.month, due_day).end_of_day
  end

  def recalculate_balances_from(date)
    Logic::RecalculateBalancesService.new(user: current_user, context: current_context, year: date.year, month: date.month).call
  end

  def render_payment_failure_success
    build_index_context_from_selection? || build_index_context(current_context.cash_installments)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:center_container, Views::CashTransactions::Index.new(index_context: @index_context, mobile: @mobile)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: I18n.t("cash_transactions.payment_failure.reported") })
        ]
      end
    end
  end
end
