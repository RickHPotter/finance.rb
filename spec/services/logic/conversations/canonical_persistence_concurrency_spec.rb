# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Canonical conversation persistence", :non_transactional do
  self.use_transactional_tests = false

  it "lets the database choose one winner when two canonical main threads race" do
    rikki = create(:user, :random)
    gigi = create(:user, :random)
    friendship = create(:friendship, :accepted, user: rikki, friend: gigi)
    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do
      Thread.new do
        ready << true
        wait_for_signal(release, description: "the conversation insert race release")
        ActiveRecord::Base.connection_pool.with_connection do
          conversation = Conversation.new(friendship:, kind: :human)
          conversation.conversation_participants.build(user: rikki)
          conversation.conversation_participants.build(user: gigi)
          conversation.save!
          conversation.id
        rescue ActiveRecord::RecordNotUnique
          :duplicate
        end
      end
    end
    2.times { wait_for_signal(ready, description: "a conversation insert racer to become ready") }
    2.times { release << true }
    results = threads.map { |thread| thread_value(thread, description: "a conversation insert racer") }

    expect(results.count { |result| result.is_a?(Integer) }).to eq(1)
    expect(results).to include(:duplicate)
    expect(Conversation.where(friendship:, kind: :human, scenario_key: nil).count).to eq(1)
  ensure
    Conversation.where(friendship_id: friendship&.id).destroy_all
    friendship&.destroy!
  end
end
