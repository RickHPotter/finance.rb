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

    friend_user_reference = friend_user.cash_transactions.find_by(reference_transactable: self)
    return if action == :destroy && friend_user_reference.blank?

    I18n.locale = friend_user.locale

    conversation = find_or_create_conversation(user, friend_user)
    message = conversation.messages.new(user:, reference_transactable: self)
    message.reference_transactable = friend_user_reference if action == :destroy

    entity_transaction = entity_transactions.find_by(entity_id: friend.id)
    return if entity_transaction.nil? && action != :destroy

    save_message(message, friend_user, entity_transaction&.exchanges&.order(:number, :date), action)
  end

  def find_or_create_conversation(user, friend_user)
    conversation = Conversation.joins(:conversation_participants)
                               .where(conversation_participants: { user_id: [ user.id, friend_user.id ] })
                               .group("conversations.id")
                               .having("COUNT(DISTINCT conversation_participants.user_id) = 2")
                               .first

    conversation || Conversation.fast_create(user, friend_user)
  end

  def save_message(message, friend_user, exchanges, action)
    create_body(message, friend_user, exchanges, action)
    create_headers(message, friend_user, exchanges, action)

    return false if message.headers.present? && Message.exists?(conversation: message.conversation, headers: message.headers)

    message.save

    supersede_previous_messages(message.conversation, message) if action != :create
  end

  def create_body(message, friend_user, exchanges, action)
    new_line = "\n"
    body = [ "<b>#{model_attribute(message, :hello)}, #{friend_user.first_name}!</b>#{new_line * 2}" ]

    case action
    when :create
      body << (model_attribute(message, :ivemadeatransactiononyou) + (new_line * 2))
      body.concat(transaction_details(exchanges, new_line))
      body << (new_line + model_attribute(message, :click_down_below))
    when :update
      body << (model_attribute(message, :iveupdatedatransactiononyou) + (new_line * 2))
      body.concat(transaction_details(exchanges, new_line))
      body << (new_line + model_attribute(message, :click_down_below))
    when :destroy
      body << (model_attribute(message, :ivedeletedatransactiononyou) + (new_line * 2))
      body.concat(transaction_details(exchanges, new_line))
    end

    message.body = body.join
  end

  def transaction_details(exchanges, new_line)
    return [] unless exchanges

    [
      "<b>#{model_attribute(self, :self).upcase}</b>#{new_line}",
      "#{model_attribute(self, :description)}: #{description}#{new_line}",
      "#{model_attribute(self, :date)}: #{I18n.l(date, format: :long)}#{new_line}",
      "#{model_attribute(self, :reference_month_year)}: #{month_year}#{new_line}",
      "#{model_attribute(self, :price)}: #{from_cent_based_to_float(exchanges.sum(:price), 'R$')}#{new_line}",
      "#{model_attribute(self, :installments_count)}: #{exchanges.count}#{new_line * 2}",
      "<b>#{model_attribute(installments.first, :self).upcase}</b>#{new_line}"
    ].tap do |details|
      exchanges.each do |exchange|
        details << " - #{exchange.number} [#{I18n.l(exchange.date, format: :long)}] #{from_cent_based_to_float(exchange.price, 'R$')}#{new_line}"
      end
    end
  end

  def create_headers(message, friend_user, exchanges, action)
    return if action == :destroy
    return if exchanges.blank?

    transaction_type = exchanges.first.entity_transaction.transactable_type

    message.headers = if transaction_type == "CardTransaction"
                        build_card_transaction_headers(friend_user, exchanges).to_json
                      else
                        build_cash_transaction_headers(friend_user, exchanges).to_json
                      end
  end

  def build_card_transaction_headers(friend_user, exchanges)
    exchanges = exchanges.map do |exchange|
      { **exchange.slice(:number, :date, :month, :year), price: exchange.price * -1 }
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
      installment.slice(:number, :date, :month, :year).merge(price: installment.price * -1)
    end

    exchanges_attributes = exchanges.map do |exchange|
      exchange.slice(:number, :date, :month, :year).merge(price: exchange.price * -1)
    end

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

  def build_cash_reimbursement_headers(friend_user, exchanges, intent)
    counterpart_entity_id = friend_user.entities.that_are_users.find_by(entity_user: user).id
    cash_installments_attributes = exchanges.map do |exchange|
      exchange.slice(:number, :date, :month, :year).merge(price: exchange.price * -1)
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
    previous_messages = conversation.messages.where(reference_transactable: self).where(superseded_by_id: nil).where.not(id: new_message.id)

    previous_messages.update_all(superseded_by_id: new_message.id)
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
end
