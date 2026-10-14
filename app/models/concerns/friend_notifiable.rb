# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module FriendNotifiable # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  include TranslateHelper

  included do
    # @callbacks ..............................................................
    after_create -> { notify_friends(:create) }
    after_update -> { notify_friends(:update) }
    after_destroy -> { notify_friends(:destroy) }
  end

  def notification_message_reference_family
    family_root =
      if respond_to?(:reference_root_transaction)
        reference_root_transaction.presence || self
      else
        self
      end

    return [ family_root ].compact unless family_root.is_a?(CashTransaction) || family_root.is_a?(CardTransaction)

    CashTransaction.reference_family_for(family_root)
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def notify_friends_for_line_item_change(action)
    notify_friends(action)
  end

  def notify_friends(action)
    return if applying_actionable_message?

    action = notification_action_for_transition(action)
    return if action.blank?

    friends = notification_friends(action)

    return if friends.empty?

    friends.each do |friend|
      notify_friend(friend, action)
    end

    I18n.locale = user.locale
  end

  def notification_action_for_transition(action)
    return action if action == :create || !not_exchange?
    return if was_not_exchange?
    return action if action == :update && composite_notification_history? && no_current_friend_exchange_allocations?

    :destroy
  end

  def notification_friends(action)
    entity_transactions = friend_notification_entity_transactions
    entity_ids = if action == :destroy
                   entity_transactions.select { |et| et.exchanges_count.zero? }.map(&:entity_id).presence || original_entities
                 else
                   entity_transactions.select { |et| et.exchanges_count.positive? }.map(&:entity_id)
                 end
    friends = user.entities.where(id: entity_ids).that_are_users
    return friends if action == :create || !composite_notification_history?

    friends.or(user.entities.where(id: previous_notification_friend_entity_ids).that_are_users)
  end

  def notify_friend(friend, action)
    friend_user = friend.entity_user

    friendship = user.friendship_with(friend_user)
    return unless friendship&.accepted_state?

    return if reference_transactable&.user == friend_user

    receiver_context = receiver_context_for(friend_user)
    friend_user_reference = CashTransaction.first_reference_descendant_for(self, scope: receiver_context.cash_transactions)
    return if action == :destroy && friend_user_reference.blank?

    I18n.locale = friend_user.locale

    conversation = find_or_create_conversation(user, friendship, scenario_key: receiver_context.scenario_key)
    destroy_message_reference = destroy_message_reference_transactable(friend_user_reference)
    message = conversation.messages.new(user:, reference_transactable: action == :destroy ? destroy_message_reference : self)

    save_friend_notification_groups(
      conversation:,
      message:,
      friend_user:,
      friend:,
      receiver_context:,
      action:,
      destroy_reference: friend_user_reference
    )
  end

  def save_friend_notification_groups(conversation:, message:, friend_user:, friend:, receiver_context:, action:, destroy_reference:)
    entity_transactions_for_friend = friend_notification_entity_transactions.select { |et| et.entity_id == friend.id }
    exchange_groups = notification_exchange_groups(entity_transactions_for_friend, action)
    removed_intent_messages = removed_notification_intent_messages(conversation, exchange_groups.keys) if action == :update
    return if entity_transactions_for_friend.empty? && action != :destroy && removed_intent_messages.blank?

    current_group_messages = save_notification_exchange_groups(
      exchange_groups:, conversation:, message:, friend_user:, receiver_context:, action:, destroy_reference:
    )
    current_group_messages = current_notification_group_messages(conversation, exchange_groups.keys) if current_group_messages.empty?

    destroy_removed_notification_intent_groups(
      conversation:,
      friend_user:,
      receiver_context:,
      removed_messages: removed_intent_messages || [],
      current_messages: current_group_messages
    )
  end

  def notification_exchange_groups(entity_transactions, action)
    exchanges = Exchange.where(entity_transaction_id: entity_transactions.map(&:id)).order(:number, :date).to_a
    return { nil => exchanges } unless is_a?(CashTransaction) && composite? && action != :destroy

    exchanges.group_by { |exchange| notification_intent_for_exchange(exchange) }
  end

  def current_notification_group_messages(conversation, intents)
    conversation.messages
                .where(reference_transactable_type: self.class.name, reference_transactable_id: id)
                .where(body: %w[notification:create notification:update], superseded_by_id: nil)
                .select { |current_message| intents.include?(current_message.replay_payload&.dig("intent")) }
  end

  def save_notification_exchange_groups(exchange_groups:, conversation:, message:, friend_user:, receiver_context:, action:, destroy_reference:)
    group_actions = exchange_groups.keys.index_with do |intent|
      notification_action_for_group(conversation, intent, action, exchange_groups.size, receiver_context:)
    end
    ordered_groups = exchange_groups.sort_by { |intent, _exchanges| group_actions[intent] == :update ? 0 : 1 }
    superseded_previous = false

    ordered_groups.each_with_index.filter_map do |(intent, grouped_exchanges), index|
      grouped_message = index.zero? ? message : conversation.messages.new(user:, reference_transactable: self)
      group_action = group_actions[intent]
      saved = save_message(
        grouped_message,
        friend_user,
        aggregate_notification_exchanges(grouped_exchanges),
        group_action,
        destroy_reference:,
        intent:,
        supersede_previous: group_action == :update && !superseded_previous,
        preserve_other_intents: exchange_groups.size > 1
      )
      superseded_previous ||= group_action == :update && saved
      grouped_message if saved
    end
  end

  def notification_action_for_group(conversation, intent, action, group_count, receiver_context:)
    return action unless action == :update && is_a?(CashTransaction) && composite?

    previous_messages = conversation.messages
                                    .where(reference_transactable_type: self.class.name, reference_transactable_id: id)
                                    .where(body: %w[notification:create notification:update])
                                    .to_a
    active_messages = previous_messages.select { |previous| previous.superseded_by_id.nil? }
    return :update if active_messages.any? { |previous| previous.replay_payload&.dig("intent") == intent }
    return :update if previous_messages.any? do |previous|
      previous.replay_payload&.dig("intent") == intent && previous_notification_target_exists?(previous, receiver_context)
    end
    return :update if group_count == 1 && active_messages.one?

    :create
  end

  def previous_notification_target_exists?(message, context)
    target = message.local_reference_for(context:)
    return false unless target

    category_ids = Array(message.replay_payload&.fetch("category_ids", nil)).flatten.compact.map(&:to_i)
    (target.category_transactions.map(&:category_id) & category_ids).present?
  end

  def removed_notification_intent_messages(conversation, current_intents)
    return [] unless is_a?(CashTransaction)
    return [] unless composite? || current_intents.compact.empty?

    current_intents = current_intents.compact
    conversation.messages
                .where(reference_transactable_type: self.class.name, reference_transactable_id: id)
                .where(body: %w[notification:create notification:update])
                .select do |previous_message|
      previous_intent = previous_message.replay_payload&.dig("intent")
      previous_intent.present? && !current_intents.include?(previous_intent)
    end
  end

  def destroy_removed_notification_intent_groups(conversation:, friend_user:, receiver_context:, removed_messages:, current_messages:)
    current_target_ids = notification_group_target_ids(current_messages, receiver_context)
    current_category_ids = current_messages.flat_map { |notification| Array(notification.replay_payload&.fetch("category_ids", nil)) }
                                           .flatten.compact.map(&:to_i)
    stale_targets = removed_messages.filter_map { |previous| previous.local_reference_for(context: receiver_context) }.uniq(&:id)
    fallback_preserved_target_id = unique_stale_target_id(stale_targets) if current_messages.one? && current_target_ids.empty?

    stale_targets.each do |stale_target|
      next if notification_target_is_current?(stale_target, current_target_ids, current_category_ids, fallback_preserved_target_id)

      create_removed_intent_destroy_message(conversation, friend_user, stale_target)
    end
  end

  def notification_group_target_ids(messages, context)
    messages.filter_map { |notification| notification.local_reference_for(context:)&.id }
  end

  def unique_stale_target_id(stale_targets)
    stale_targets.first.id if stale_targets.map(&:id).uniq.one?
  end

  def notification_target_is_current?(target, current_target_ids, current_category_ids, fallback_target_id)
    return true if current_target_ids.include?(target.id) || fallback_target_id == target.id

    (target.category_transactions.map(&:category_id) & current_category_ids).present?
  end

  def create_removed_intent_destroy_message(conversation, friend_user, target)
    destroy_message = conversation.messages.new(user:, reference_transactable: target, body: "notification:destroy")
    create_headers(destroy_message, friend_user, [], :destroy, destroy_reference: target)
    destroy_message.save
  end

  def find_or_create_conversation(user, friendship, scenario_key:)
    Logic::Conversations::Resolve.call(actor: user, friendship:, kind: :assistant, scenario_key:)
  end

  def save_message(message, friend_user, exchanges, action, destroy_reference: nil, intent: nil, supersede_previous: true,
                   preserve_other_intents: false)
    create_body(message, friend_user, exchanges, action)
    create_headers(message, friend_user, exchanges, action, destroy_reference:, intent:)

    return false if message.headers.present? && Message.latest.exists?(conversation: message.conversation, headers: message.headers)

    message.save

    return unless action != :create && supersede_previous

    supersede_previous_messages(message.conversation, message, preserve_other_intents:)
  end

  def create_body(message, _friend_user, _exchanges, action)
    message.body = "notification:#{action}"
  end

  def create_headers(message, friend_user, exchanges, action, destroy_reference: nil, intent: nil)
    if action == :destroy
      message.headers = {
        version: "message_notification_v2",
        event: build_destroy_notification_event(message, friend_user, destroy_reference),
        replay: nil
      }.to_json

      return
    end

    return if exchanges.blank?

    transaction_type = model_name.name

    replay_payload = if action == :destroy
                       nil
                     elsif transaction_type == "CardTransaction"
                       build_card_transaction_headers(friend_user, exchanges)
                     else
                       build_cash_transaction_headers(friend_user, exchanges, intent:)
                     end

    # If no mirror entity exists on the friend's side yet (friendship accepted but
    # ReconcileEntityService hasn't run), the payload builder returns nil — skip the
    # notification entirely rather than saving a non-replayable stub message.
    return if replay_payload.nil?

    message.headers = {
      version: "message_notification_v2",
      event: build_notification_event(friend_user, exchanges, action, transaction_type),
      replay: replay_payload
    }.to_json
  end

  def build_destroy_notification_event(message, friend_user, destroy_reference = nil)
    transaction = destroy_reference || message.reference_transactable || self
    installments = transaction.installments.order(:number, :date)

    {
      action: "destroy",
      receiver_first_name: friend_user.first_name,
      transaction_type: transaction.class.name,
      details: {
        transaction_label: model_attribute(transaction.class, :self),
        description: transaction.description,
        date: transaction.date&.iso8601,
        reference_month_year: transaction.respond_to?(:month_year) ? transaction.month_year : nil,
        price: transaction.respond_to?(:price) ? transaction.price : nil,
        installments_count: installments.size,
        installments: installments.map { |installment| installment.slice(:number, :price).merge(date: installment.date&.iso8601) }
      }
    }
  end

  def build_notification_event(friend_user, exchanges, action, transaction_type)
    {
      action: action.to_s,
      receiver_first_name: friend_user.first_name,
      transaction_type:,
      details: {
        transaction_label: model_attribute(self, :self),
        description:,
        date: date&.iso8601,
        reference_month_year: month_year,
        price: exchanges.sum(&:price),
        installments_count: exchanges.size,
        installments: exchanges.map { |exchange| exchange.slice(:number, :price).merge(date: exchange.date&.iso8601) }
      }
    }
  end

  def build_card_transaction_headers(friend_user, exchanges)
    entity_id = friend_user.entities.that_are_users.where_entity_user(user).first&.id
    return unless entity_id

    exchanges = exchanges.map do |exchange|
      { **exchange.slice(:number, :date, :month, :year), price: exchange.price * -1, paid: exchange.mirrored_paid? }
    end

    price = exchanges.sum { |exchange| exchange[:price] }

    {
      id:,
      type:,
      description:,
      price:,
      date:,
      month:,
      year:,
      category_ids: counterpart_return_category_id_for(friend_user),
      entity_ids: entity_id,
      cash_installments_attributes: exchanges
    }
  end

  def build_cash_transaction_headers(friend_user, exchanges, intent: nil)
    intent = friend_notification_intent_for(friend_user, explicit_intent: intent)

    if intent == "reimbursement"
      build_cash_reimbursement_headers(friend_user, exchanges, intent)
    else
      build_cash_loan_headers(friend_user, exchanges, intent)
    end
  end

  def build_cash_loan_headers(friend_user, exchanges, intent)
    entity_id = friend_user.entities.that_are_users.where_entity_user(user).first&.id
    return unless entity_id

    cash_installments_attributes = cash_installments_for_exchanges(exchanges)
    exchanges_attributes = cash_loan_exchange_attributes(exchanges)

    installments_price = cash_installments_attributes.sum { |installment| installment[:price] }
    exchanges_price = exchanges_attributes.sum { |exchange| exchange[:price] }

    {
      id:,
      type:,
      version: "cash_exchange_v2",
      intent:,
      description:,
      price: installments_price,
      date:,
      month:,
      year:,
      category_ids: friend_user.categories.find_by(category_name: "EXCHANGE").id,
      cash_installments_attributes:,
      entity_transactions_attributes: [
        {
          is_payer: true,
          price: exchanges_price,
          price_to_be_returned: exchanges_price,
          entity_id:,
          exchanges_count: exchanges_attributes.count,
          exchanges_attributes:
        }
      ]
    }
  end

  def cash_installments_for_exchanges(exchanges)
    # A composite transaction can have multiple LineItems sharing the same installment number.
    # The parent installment total therefore cannot represent the amount shared by one intent
    # group; derive the counterpart amount from that group's exchanges instead.
    aggregated_exchange_attributes(exchanges).sort_by { |installment| [ installment[:number], installment[:date] ] }
  end

  def cash_loan_exchange_attributes(exchanges)
    aggregated_exchange_attributes(exchanges, group_by_exchange_type: true)
      .map { |exchange| exchange.merge(price: -exchange[:price]) }
      .sort_by { |exchange| [ exchange[:number], exchange[:date] ] }
  end

  def aggregated_exchange_attributes(exchanges, group_by_exchange_type: false)
    grouped_exchanges = exchanges.group_by do |exchange|
      [ exchange.number, exchange.month, exchange.year, (exchange.exchange_type if group_by_exchange_type) ]
    end

    grouped_exchanges.map do |(number, month, year, exchange_type), exchange_group|
      date = exchange_group.map(&:date).compact.min
      # The request transaction is incoming for the recipient, while its
      # exchange schedule represents the recipient's repayment obligation.
      attributes = { number:, date:, month:, year:, price: exchange_group.sum { |exchange| exchange.price.to_i.abs } }
      attributes[:exchange_type] = exchange_type if group_by_exchange_type
      attributes
    end
  end

  def build_cash_reimbursement_headers(friend_user, exchanges, intent)
    counterpart_entity_id = friend_user.entities.that_are_users.where_entity_user(user).first&.id
    return unless counterpart_entity_id

    # Structural notifications carry shape only — payment state travels via paid_state_sync messages.
    cash_installments_attributes = exchanges.map do |exchange|
      exchange.slice(:number, :date, :month, :year).merge(price: exchange.price * -1)
    end

    installments_price = cash_installments_attributes.sum { |installment| installment[:price] }

    {
      id:,
      type:,
      version: "cash_exchange_v2",
      intent:,
      description:,
      price: installments_price,
      date:,
      month:,
      year:,
      category_ids: counterpart_return_category_id_for(friend_user),
      entity_ids: counterpart_entity_id,
      cash_installments_attributes:,
      entity_transactions_attributes: [
        {
          is_payer: false,
          price: 0,
          price_to_be_returned: 0,
          entity_id: counterpart_entity_id,
          exchanges_count: 0,
          exchanges_attributes: []
        }
      ]
    }
  end

  def friend_notification_intent_for(friend_user, explicit_intent: nil)
    explicit_intent ||= respond_to?(:friend_notification_intent) ? friend_notification_intent.presence : nil
    return explicit_intent if explicit_intent.in?(%w[loan reimbursement])

    return "reimbursement" if reimbursement_notification?(friend_user)

    "loan"
  end

  def notification_intent_for_exchange(exchange)
    line_item = exchange.entity_transaction.transactable
    return line_item.friend_notification_intent if line_item.is_a?(LineItem)

    friend_notification_intent_for(exchange.entity_transaction.entity&.entity_user)
  end

  def supersede_previous_messages(conversation, new_message, preserve_other_intents: false)
    previous_messages = conversation.messages
                                    .merge(reference_scope_for(notification_message_reference_family))
                                    .where(superseded_by_id: nil)
                                    .where.not(id: new_message.id)
    if preserve_other_intents && new_message.replay_payload&.dig("intent").present?
      matching_message_ids = previous_messages.filter_map do |previous_message|
        next unless previous_message.replay_payload&.dig("intent") == new_message.replay_payload["intent"]

        previous_message.id
      end
      previous_messages = previous_messages.where(id: matching_message_ids)
    end

    Logic::Messages::Transition.expire_scope!(previous_messages, superseded_by: new_message)
  end

  def reference_scope_for(references)
    grouped_references = references.compact.uniq { |reference| [ reference.class.name, reference.id ] }.group_by(&:class)

    grouped_references.values.map do |group|
      Message.where(
        reference_transactable_type: group.first.class.name,
        reference_transactable_id: group.map(&:id)
      )
    end.reduce(Message.none, &:or)
  end

  def notification_context
    context || user&.main_context
  end

  def destroy_message_reference_transactable(friend_user_reference)
    return self if friend_user_reference.blank?

    parent_reference = friend_user_reference.try(:reference_transactable)
    return parent_reference if parent_reference.is_a?(CashTransaction) && parent_reference.persisted? && !parent_reference.destroyed?

    friend_user_reference
  end

  def receiver_context_for(friend_user)
    sender_context = notification_context
    return friend_user.ensure_main_context! if sender_context.blank? || sender_context.main? || sender_context.scenario_key.blank?

    friend_user.contexts.find_by(scenario_key: sender_context.scenario_key) ||
      Logic::ContextCloneService.new(
        source_context: friend_user.ensure_main_context!,
        name: next_receiver_context_name_for(friend_user, sender_context.name),
        description: sender_context.description,
        scenario_key: sender_context.scenario_key
      ).call
  end

  def next_receiver_context_name_for(friend_user, base_name)
    return base_name unless friend_user.contexts.exists?(name: base_name)

    suffix = 2
    loop do
      candidate = "#{base_name} #{suffix}"
      return candidate unless friend_user.contexts.exists?(name: candidate)

      suffix += 1
    end
  end

  def counterpart_return_category_id_for(friend_user)
    my_category_names = categories.pluck(:category_name)
    counterpart_name = if my_category_names.include?("BORROW RETURN")
                         "LEND RETURN"
                       else
                         "BORROW RETURN"
                       end

    friend_user.categories.find_by(category_name: counterpart_name)&.id
  end

  # HELPER VALUE METHODS
  def exchange_category
    @exchange_category ||= user.categories.find_by(category_name: "EXCHANGE")
  end

  def type
    model_name.name
  end

  # HELPER BOOLEAN METHODS
  def not_exchange?
    friend_notification_category_ids.exclude?(exchange_category.id)
  end

  def was_not_exchange?
    return false if composite_notification_history?

    original_categories.blank? || original_categories.exclude?(exchange_category.id)
  end

  def composite_notification_history?
    is_a?(CashTransaction) && composite? && previous_notification_messages.exists?
  end

  def previous_notification_messages
    Message.where(reference_transactable_type: self.class.name, reference_transactable_id: id)
           .where(body: %w[notification:create notification:update])
  end

  def previous_notification_friend_entity_ids
    recipient_users = previous_notification_messages.filter_map do |message|
      message.conversation.conversation_participants.find { |participant| participant.user_id != user_id }&.user
    end.uniq(&:id)

    recipient_users.flat_map { |recipient_user| user.entities.that_are_users.where_entity_user(recipient_user).pluck(:id) }.uniq
  end

  def no_current_friend_exchange_allocations?
    friend_entity_ids = previous_notification_friend_entity_ids
    friend_notification_entity_transactions.none? do |entity_transaction|
      friend_entity_ids.include?(entity_transaction.entity_id) && entity_transaction.exchanges_count.positive?
    end
  end

  def reimbursement_notification?(friend_user)
    category_names = Category.where(id: friend_notification_category_ids).pluck(:category_name)
    return true if (category_names - [ "EXCHANGE" ]).present?

    counterpart_entity_id = user.entities.that_are_users.where_entity_user(friend_user).first&.id

    friend_notification_entity_transactions.any? { |et| et.entity_id != counterpart_entity_id }
  end

  def friend_notification_entity_transactions
    return entity_transactions.to_a unless respond_to?(:composite?) && composite?

    active_line_items.flat_map { |line_item| line_item.entity_transactions.reject(&:marked_for_destruction?) }
  end

  def friend_notification_category_ids
    return category_transactions.pluck(:category_id) unless respond_to?(:composite?) && composite?

    active_line_items.filter_map(&:category_id)
  end

  def aggregate_notification_exchanges(exchanges)
    exchanges.group_by { |exchange| [ exchange.number, exchange.date, exchange.month, exchange.year, exchange.exchange_type, exchange.bound_type ] }
             .values.map do |group|
      group.first.dup.tap { |exchange| exchange.price = group.sum(&:price) }
    end
  end

  def applying_actionable_message?
    respond_to?(:source_message_id) && source_message_id.present?
  end
end
