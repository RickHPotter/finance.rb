# frozen_string_literal: true

class Message < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
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

  # @scopes ...................................................................
  scope :unread, -> { where(read_at: nil) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
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
