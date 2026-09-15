# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::Resolve, :non_transactional do
  self.use_transactional_tests = false

  it "returns the same canonical conversation to two concurrent callers" do
    rikki = create(:user, :random)
    gigi = create(:user, :random)
    friendship = create(:friendship, :accepted, user: rikki, friend: gigi)
    ready = Queue.new
    release = Queue.new
    threads = [ rikki, gigi ].map do |actor|
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the conversation resolver race release")
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.call(actor:, friendship: Friendship.find(friendship.id), kind: :human).id
        end
      end
    end
    2.times { wait_for_signal(ready, description: "a conversation resolver to become ready") }
    2.times { release << true }
    conversation_ids = threads.map { |thread| thread_value(thread, description: "a conversation resolver") }

    expect(conversation_ids.uniq.one?).to be(true)
    expect(Conversation.where(friendship:, kind: :human, scenario_key: nil).count).to eq(1)
  ensure
    Conversation.where(friendship_id: friendship&.id).destroy_all
    friendship&.destroy!
  end
end
