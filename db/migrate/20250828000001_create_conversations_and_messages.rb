# frozen_string_literal: true

class CreateConversationsAndMessages < ActiveRecord::Migration[8.0]
  def change
    # FIXME: remove later BEGIN
    drop_table :messages, if_exists: true
    drop_table :conversation_participants, if_exists: true
    drop_table :conversations, if_exists: true
    # FIXME: remove later END

    return if table_exists?(:conversations) && table_exists?(:conversation_participants) && table_exists?(:messages)

    create_table :conversations do |t|
      t.timestamps
    end

    create_table :conversation_participants do |t|
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body
      t.datetime :read_at

      t.timestamps
    end

    return if User.count < 2

    # FIXME: remove later
    conversation = Conversation.new
    conversation.conversation_participants.build([ { user: User.first }, { user: User.second } ])
    conversation.save
  end
end
