# frozen_string_literal: true

class Message < ApplicationRecord
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
    return body unless notification_payload_v2?

    render_notification_body
  end

  def preview_body
    return body.to_s.tr("\n", " ").presence || "" unless notification_payload_v2?

    [
      I18n.t("activerecord.attributes.message.notification_actions.#{notification_action}"),
      notification_event.dig("details", "description")
    ].compact.join(": ")
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def parsed_headers
    @parsed_headers ||= JSON.parse(headers || "{}")
  rescue JSON::ParserError
    {}
  end

  def notification_payload_v2?
    parsed_headers["version"] == "message_notification_v2"
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

    body = [ "<b>#{model_attribute(self, :hello)}, #{notification_event['receiver_first_name']}!</b>#{new_line * 2}" ]

    body << "#{model_attribute(self, notification_action_message_key)}#{new_line * 2}"
    body << "<b>#{details['transaction_label'].to_s.upcase}</b>#{new_line}"
    body << "#{model_attribute(notification_event['transaction_type'].constantize, :description)}: #{details['description']}#{new_line}"
    body << "#{model_attribute(notification_event['transaction_type'].constantize, :date)}: #{I18n.l(Date.parse(details['date']), format: :long)}#{new_line}"
    body << "#{model_attribute(notification_event['transaction_type'].constantize, :reference_month_year)}: #{details['reference_month_year']}#{new_line}"
    body << "#{model_attribute(notification_event['transaction_type'].constantize, :price)}: #{from_cent_based_to_float(details['price'], 'R$')}#{new_line}"
    body << "#{model_attribute(notification_event['transaction_type'].constantize, :installments_count)}: #{details['installments_count']}#{new_line * 2}"
    body << "<b>#{model_attribute(installment_class(notification_event['transaction_type']), :self).upcase}</b>#{new_line}"

    installments.each do |installment|
      installment_date = installment["date"].present? ? I18n.l(Date.parse(installment["date"]), format: :long) : installment["date"]
      body << " - #{installment['number']} [#{installment_date}] #{from_cent_based_to_float(installment['price'], 'R$')}#{new_line}"
    end

    body << "#{new_line}#{model_attribute(self, :click_down_below)}" if %w[create update].include?(notification_action)

    body.join
  rescue NameError, Date::Error
    body
  end

  def installment_class(transaction_type)
    transaction_type.to_s.sub("Transaction", "Installment").constantize
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
