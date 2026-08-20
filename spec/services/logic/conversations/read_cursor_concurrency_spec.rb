# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversation participant read cursor concurrency" do
  self.use_transactional_tests = false

  it "keeps the greatest visible message when two views advance concurrently" do
    rikki = create(:user, :random)
    gigi = create(:user, :random)
    friendship = create(:friendship, :accepted, user: rikki, friend: gigi)
    conversation = Logic::Conversations::Resolve.call(actor: rikki, friendship:, kind: :human)
    first = conversation.messages.create!(user: gigi, body: "First")
    second = conversation.messages.create!(user: gigi, body: "Second")
    participant_id = conversation.participant_for!(rikki).id
    ready = Queue.new
    release = Queue.new
    threads = [ first, second ].map do |message|
      Thread.new do
        ready << true
        release.pop
        ActiveRecord::Base.connection_pool.with_connection do
          ConversationParticipant.find(participant_id).advance_read_cursor_to!(Message.find(message.id))
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:value)

    expect(ConversationParticipant.find(participant_id).last_read_message_id).to eq(second.id)
  ensure
    Conversation.where(friendship_id: friendship&.id).destroy_all
    friendship&.destroy!
  end
end
