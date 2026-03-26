# frozen_string_literal: true

class Message < ApplicationRecord # rubocop:disable Metrics/ClassLength
  # @extends ..................................................................
  # @includes .................................................................
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :conversation
  belongs_to :user
  belongs_to :superseded_by, class_name: "Message", optional: true
  has_one :supersedes, class_name: "Message", foreign_key: "superseded_by_id"
  belongs_to :reference_transactable, polymorphic: true, optional: true

  # @validations ..............................................................
  validates :body, presence: true

  # @callbacks ................................................................
  after_create_commit do
    broadcast_append_to conversation,
                        target: "messages_#{conversation.id}",
                        html: ApplicationController.render(Views::Messages::Message.new(message: self), layout: false)
  end
  after_create_commit :send_email, if: -> { Rails.env.production? }

  # @scopes ...................................................................
  scope :unread, -> { where(read_at: nil) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def transaction_notification_message?
    return false if paid_state_sync_message?
    return %w[create update].include?(notification_action) if notification_payload_v2?

    headers.present?
  end

  def transaction_destroy_notification_message?
    return notification_action == "destroy" if notification_payload_v2?

    headers.blank? && reference_transactable.present?
  end

  def human_message?
    return false if transaction_notification_message? || transaction_destroy_notification_message?

    headers.blank? && reference_transactable.blank?
  end

  def backfill_kind
    return "transaction_notification" if transaction_notification_message?
    return "transaction_destroy_notification" if transaction_destroy_notification_message?

    "human"
  end

  def replay_payload
    return if headers.blank?

    return parsed_headers["replay"] if notification_payload_v2?

    parsed_headers
  end

  def rendered_body
    return render_paid_state_sync_body if paid_state_sync_message?
    return body unless notification_payload_v2?

    render_notification_body
  end

  def preview_body
    return render_paid_state_sync_preview if paid_state_sync_message?
    return body.to_s.tr("\n", " ").presence || "" unless notification_payload_v2?

    [
      I18n.t("activerecord.attributes.message.notification_actions.#{notification_action}"),
      notification_event.dig("details", "description")
    ].compact.join(": ")
  end

  def notification_payload_v2?
    parsed_headers["version"] == "message_notification_v2"
  end

  def paid_state_sync_message?
    parsed_headers["version"] == "message_paid_state_v1"
  end

  def applied?
    applied_at.present?
  end

  def action_button_key(local_reference_exists:)
    return :ok if paid_state_sync_message?
    return :destroy if transaction_destroy_notification_message?
    return :edit if applied? && local_reference_exists
    return :correct if notification_action == "update" && local_reference_exists
    return :create unless local_reference_exists

    :edit
  end

  def completed_message_key
    return :already_acknowledged if paid_state_sync_message?

    {
      "create" => :already_created,
      "update" => :already_updated,
      "destroy" => :already_destroyed
    }.fetch(notification_action, :already_updated)
  end

  def assistant_side_for(user)
    user_id == user.id ? "mine" : "theirs"
  end

  def actionable_for?(context: user.ensure_main_context!)
    return false if applied?

    action_button_key(local_reference_exists: local_reference_for(context:).present?).in?(%i[create correct destroy ok])
  end

  def local_reference_for(context:)
    cash_transactions = context.cash_transactions

    if transaction_destroy_notification_message?
      return if reference_transactable_id.blank?

      return cash_transactions.find_by(id: reference_transactable_id)
    end

    payload = replay_payload || {}
    type = payload["type"]
    id = payload["id"]
    return if type.blank? || id.blank?

    cash_transactions.find_by(reference_transactable_type: type, reference_transactable_id: id) ||
      fallback_local_reference_for(cash_transactions)
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def local_reference_exists_for?(context:)
    local_reference_for(context:).present?
  end

  def fallback_local_reference_for(cash_transactions)
    related_reference_messages.each do |candidate|
      reference = find_fallback_local_reference(cash_transactions, candidate.replay_payload || {})
      return reference if reference.present?
    end

    nil
  end

  def related_reference_messages
    @related_reference_messages ||= if reference_transactable_type.blank? || reference_transactable_id.blank?
                                      [ self ]
                                    else
                                      [ self ] + conversation.messages
                                                             .where(reference_transactable_type:, reference_transactable_id:)
                                                             .where.not(id:)
                                                             .order(applied_at: :desc, created_at: :desc)
                                                             .to_a
                                    end
  end

  def find_fallback_local_reference(cash_transactions, payload)
    relation = cash_transactions.where(description: payload["description"], price: payload["price"])
    relation = relation.where(date: Time.zone.parse(payload["date"])) if payload["date"].present?

    category_ids = Array(payload["category_ids"]).compact_blank
    entity_ids = Array(payload["entity_ids"]).compact_blank

    relation = relation.joins(:categories).where(categories: { id: category_ids }) if category_ids.present?
    relation = relation.joins(:entities).where(entities: { id: entity_ids }) if entity_ids.present?

    relation.order(created_at: :desc).first
  rescue ArgumentError
    relation.order(created_at: :desc).first
  end

  def parsed_headers
    @parsed_headers ||= JSON.parse(headers || "{}")
  rescue JSON::ParserError
    {}
  end

  def notification_action
    parsed_headers.dig("event", "action")
  end

  def notification_event
    parsed_headers.fetch("event", {})
  end

  def render_notification_body # rubocop:disable Metrics/AbcSize
    details = notification_event.fetch("details", {})
    installments = Array(details["installments"])
    new_line = "\n"
    transaction_class = notification_event["transaction_type"].constantize

    body = [ "<b>#{model_attribute(self, :hello)}, #{notification_event['receiver_first_name']}!</b>#{new_line * 2}" ]

    body << "#{model_attribute(self, notification_action_message_key)}#{new_line * 2}"
    body << "<b>#{details['transaction_label'].to_s.upcase}</b>#{new_line}"
    body << "#{model_attribute(transaction_class, :description)}: #{details['description']}#{new_line}" if details["description"].present?
    body << "#{model_attribute(transaction_class, :date)}: #{formatted_notification_date(details['date'])}#{new_line}" if details["date"].present?
    body << "#{model_attribute(transaction_class, :reference_month_year)}: #{details['reference_month_year']}#{new_line}" if details["reference_month_year"].present?
    body << "#{model_attribute(transaction_class, :price)}: #{from_cent_based_to_float(details['price'], 'R$')}#{new_line}" if details["price"].present?
    body << "#{model_attribute(transaction_class, :installments_count)}: #{details['installments_count']}#{new_line * 2}" if details["installments_count"].present?
    body << "<b>#{model_attribute(installment_class(notification_event['transaction_type']), :self).upcase}</b>#{new_line}" if installments.present?

    installments.each do |installment|
      installment_date = installment["date"].present? ? I18n.l(Date.parse(installment["date"]), format: :long) : installment["date"]
      body << " - #{installment['number']} [#{installment_date}] #{from_cent_based_to_float(installment['price'], 'R$')}#{new_line}"
    end

    body.join
  rescue NameError, Date::Error
    body
  end

  def render_paid_state_sync_body # rubocop:disable Metrics/AbcSize
    details = notification_event.fetch("details", {})
    new_line = "\n"
    state_key = notification_action == "paid" ? :ivepaidayoursharedtransaction : :iveunpaidayoursharedtransaction
    state_label_key = notification_action == "paid" ? :paid : :not_paid

    body = [ "<b>#{model_attribute(self, :hello)}, #{notification_event['receiver_first_name']}!</b>#{new_line * 2}" ]
    body << "#{model_attribute(self, state_key)}#{new_line * 2}"
    body << "<b>#{details['transaction_label'].to_s.upcase}</b>#{new_line}"
    body << "#{model_attribute(CashTransaction, :description)}: #{details['description']}#{new_line}" if details["description"].present?
    body << "#{model_attribute(CashInstallment, :cash_installment)} ##{details['installment_number']}#{new_line}" if details["installment_number"].present?
    body << "#{model_attribute(CashInstallment, state_label_key)}#{new_line}"
    body << "#{model_attribute(CashInstallment, :date)}: #{formatted_notification_date(details['date'])}#{new_line}" if details["date"].present?
    body.join
  rescue Date::Error
    body
  end

  def render_paid_state_sync_preview
    [
      I18n.t("activerecord.attributes.message.notification_actions.#{notification_action}"),
      notification_event.dig("details", "description")
    ].compact.join(": ")
  end

  def installment_class(transaction_type)
    transaction_type.to_s.sub("Transaction", "Installment").constantize
  end

  def formatted_notification_date(date)
    I18n.l(Date.parse(date), format: :long)
  end

  def notification_action_message_key
    {
      "create" => :ivemadeatransactiononyou,
      "update" => :iveupdatedatransactiononyou,
      "destroy" => :ivedeletedatransactiononyou
    }.fetch(notification_action, :ivemadeatransactiononyou)
  end

  def send_email
    title = user.full_name
    body =  model_attribute(self, :you_have_a_new_message)
    url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.com" : "localhost")

    friends_to_notify = conversation.conversation_participants.where.not(user_id: user.id)

    friends_to_notify.each do |friend|
      friend_user = friend.user
      I18n.locale = friend_user.locale

      friend_user.push_subscriptions.each do |subscription|
        WebPush.payload_send(
          message: { title:, body:, url: }.to_json,
          endpoint: subscription.endpoint,
          p256dh: subscription.p256dh,
          auth: subscription.auth,
          vapid:
        )
      end
    end

    I18n.locale = user.locale
  end

  def vapid
    {
      subject: "mailto:30fevfun@gmail.com",
      public_key: Rails.application.credentials.dig(:vapid, :public_key),
      private_key: Rails.application.credentials.dig(:vapid, :private_key)
    }
  end
end

# == Schema Information
#
# Table name: messages
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  applied_at                  :datetime         indexed
#  body                        :text
#  headers                     :text
#  read_at                     :datetime
#  reference_transactable_type :string           indexed => [reference_transactable_id]
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  conversation_id             :bigint           not null, indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type]
#  superseded_by_id            :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_messages_on_applied_at              (applied_at)
#  index_messages_on_conversation_id         (conversation_id)
#  index_messages_on_reference_transactable  (reference_transactable_type,reference_transactable_id)
#  index_messages_on_superseded_by_id        (superseded_by_id)
#  index_messages_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (superseded_by_id => messages.id)
#  fk_rails_...  (user_id => users.id)
#
