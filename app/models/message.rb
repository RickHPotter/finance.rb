# frozen_string_literal: true

class Message < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :conversation
  belongs_to :user

  # @validations ..............................................................
  validates :body, presence: true

  # @callbacks ................................................................
  after_create_commit do
    broadcast_append_to conversation,
                        target: "messages_#{conversation.id}",
                        html: ApplicationController.render(Views::Messages::Message.new(message: self), layout: false)
  end
  after_create_commit :send_email

  # @scopes ...................................................................
  scope :unread, -> { where(read_at: nil) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def send_email
    title = user.full_name
    body =  model_attribute(self, :you_have_a_new_message)
    url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.fun" : "localhost")

    friends_to_notify = conversation.conversation_participants.where.not(user_id: user.id)

    friends_to_notify.each do |friend|
      friend_user = friend.user
      I18n.locale = friend_user.locale

      friend_user.subscriptions.each do |subscription|
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
#
#  id              :bigint           not null, primary key
#  body            :text
#  headers         :text
#  read_at         :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null, indexed
#  user_id         :bigint           not null, indexed
#
# Indexes
#
#  index_messages_on_conversation_id  (conversation_id)
#  index_messages_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#
