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

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................

  protected

  def notify_friends(action)
    return if applying_actionable_message?

    if (action != :create) && not_exchange?
      return if was_not_exchange?

      action = :destroy
    end

    if action == :destroy
      user.entities.where(id: entity_transactions.where(exchanges_count: 0).pluck(:entity_id).presence || original_entities).that_are_users
    else
      user.entities.where(id: entity_transactions.where(exchanges_count: 1..).pluck(:entity_id)).that_are_users
    end => friends

    return if friends.empty?

    friends.each do |friend|
      notify_friend(friend, action)
    end

    I18n.locale = user.locale
  end

  def notify_friend(friend, action)
    friend_user = friend.entity_user

    return if reference_transactable&.user == friend_user

    receiver_context = receiver_context_for(friend_user)
    friend_user_reference = CashTransaction.first_reference_descendant_for(self, scope: receiver_context.cash_transactions)
    return if action == :destroy && friend_user_reference.blank?

    I18n.locale = friend_user.locale

    conversation = find_or_create_conversation(user, friend_user, scenario_key: receiver_context.scenario_key)
    destroy_message_reference = destroy_message_reference_transactable(friend_user_reference)
    message = conversation.messages.new(user:, reference_transactable: action == :destroy ? destroy_message_reference : self)

    entity_transaction = entity_transactions.find_by(entity_id: friend.id)
    return if entity_transaction.nil? && action != :destroy

    save_message(message, friend_user, entity_transaction&.exchanges&.order(:number, :date), action, destroy_reference: friend_user_reference)
  end

  def find_or_create_conversation(user, friend_user, scenario_key:)
    Conversation.find_or_create_assistant_between!(user, friend_user, scenario_key:)
  end

  def save_message(message, friend_user, exchanges, action, destroy_reference: nil)
    create_body(message, friend_user, exchanges, action)
    create_headers(message, friend_user, exchanges, action, destroy_reference:)

    return false if message.headers.present? && Message.exists?(conversation: message.conversation, headers: message.headers)

    message.save

    supersede_previous_messages(message.conversation, message) if action != :create
  end

  def create_body(message, _friend_user, _exchanges, action)
    message.body = "notification:#{action}"
  end

  def create_headers(message, friend_user, exchanges, action, destroy_reference: nil)
    if action == :destroy
      message.headers = {
        version: "message_notification_v2",
        event: build_destroy_notification_event(message, friend_user, destroy_reference),
        replay: nil
      }.to_json

      return
    end

    return if exchanges.blank?

    transaction_type = exchanges.first.entity_transaction.transactable_type

    replay_payload = if action == :destroy
                       nil
                     elsif transaction_type == "CardTransaction"
                       build_card_transaction_headers(friend_user, exchanges)
                     else
                       build_cash_transaction_headers(friend_user, exchanges)
                     end

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
        price: exchanges.sum(:price),
        installments_count: exchanges.count,
        installments: exchanges.map { |exchange| exchange.slice(:number, :price).merge(date: exchange.date&.iso8601) }
      }
    }
  end

  def build_card_transaction_headers(friend_user, exchanges)
    exchanges = exchanges.map do |exchange|
      { **exchange.slice(:number, :date, :month, :year), price: exchange.price * -1, paid: exchange.mirrored_paid? }
    end

    price = exchanges.pluck(:price).sum
    friend_user.entities.that_are_users.find_by(entity_user: user).id

    {
      id:,
      type:,
      description:,
      price:,
      date:,
      month:,
      year:,
      category_ids: friend_user.categories.find_by(category_name: "BORROW RETURN").id,
      entity_ids: friend_user.entities.that_are_users.find_by(entity_user: user).id,
      cash_installments_attributes: exchanges
    }
  end

  def build_cash_transaction_headers(friend_user, exchanges)
    intent = friend_notification_intent_for(friend_user)

    if intent == "reimbursement"
      build_cash_reimbursement_headers(friend_user, exchanges, intent)
    else
      build_cash_loan_headers(friend_user, exchanges, intent)
    end
  end

  def build_cash_loan_headers(friend_user, exchanges, intent)
    cash_installments_attributes = installments.order(:number, :date).map do |installment|
      installment.slice(:number, :date, :month, :year, :paid).merge(price: installment.price * -1)
    end

    exchanges_attributes = cash_loan_exchange_attributes(exchanges)

    installments_price = cash_installments_attributes.pluck(:price).sum
    exchanges_price = exchanges_attributes.pluck(:price).sum

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
          entity_id: friend_user.entities.that_are_users.find_by(entity_user: user).id,
          exchanges_count: exchanges.count,
          exchanges_attributes:
        }
      ]
    }
  end

  def cash_loan_exchange_attributes(exchanges)
    exchanges.map do |exchange|
      exchange.slice(:number, :date, :month, :year).merge(price: exchange.price * -1, paid: exchange.mirrored_paid?)
    end
  end

  def build_cash_reimbursement_headers(friend_user, exchanges, intent)
    counterpart_entity_id = friend_user.entities.that_are_users.find_by(entity_user: user).id
    paid_by_number = installments.order(:number, :date).index_by(&:number)
    cash_installments_attributes = exchanges.map do |exchange|
      exchange.slice(:number, :date, :month, :year).merge(price: exchange.price * -1, paid: paid_by_number[exchange.number]&.paid || false)
    end

    installments_price = cash_installments_attributes.pluck(:price).sum

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
      category_ids: friend_user.categories.find_by(category_name: "BORROW RETURN").id,
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

  def friend_notification_intent_for(friend_user)
    explicit_intent = respond_to?(:friend_notification_intent) ? friend_notification_intent.presence : nil
    return explicit_intent if explicit_intent.in?(%w[loan reimbursement])

    return "reimbursement" if reimbursement_notification?(friend_user)

    "loan"
  end

  def supersede_previous_messages(conversation, new_message)
    previous_messages = conversation.messages
                                    .merge(reference_scope_for(notification_message_reference_family))
                                    .where(superseded_by_id: nil)
                                    .where.not(id: new_message.id)

    previous_messages.update_all(superseded_by_id: new_message.id)
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

  # HELPER VALUE METHODS
  def exchange_category
    @exchange_category ||= user.categories.find_by(category_name: "EXCHANGE")
  end

  def type
    model_name.name
  end

  # HELPER BOOLEAN METHODS
  def not_exchange?
    category_transactions.pluck(:category_id).exclude?(exchange_category.id)
  end

  def was_not_exchange?
    original_categories.blank? || original_categories.exclude?(exchange_category.id)
  end

  def reimbursement_notification?(friend_user)
    category_names = categories.pluck(:category_name)
    return true if (category_names - [ "EXCHANGE" ]).present?

    counterpart_entity_id = user.entities.that_are_users.find_by(entity_user: friend_user)&.id

    entity_transactions.where.not(entity_id: counterpart_entity_id).exists?
  end

  def applying_actionable_message?
    respond_to?(:source_message_id) && source_message_id.present?
  end
end
