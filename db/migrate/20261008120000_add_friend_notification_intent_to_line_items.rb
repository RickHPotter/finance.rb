# frozen_string_literal: true

class AddFriendNotificationIntentToLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :line_items, :friend_notification_intent, :string
  end
end
