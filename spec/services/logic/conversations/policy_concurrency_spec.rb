# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversation policy revocation concurrency", :non_transactional do
  self.use_transactional_tests = false

  it "serializes friendship revocation after an authorized mutation" do
    user = create(:user, :random)
    friend = create(:user, :random)
    friendship = create(:friendship, :accepted, user:, friend:)
    conversation = resolve_human_conversation(user, friend)
    participant_id = conversation.participant_for!(user).id
    mutation_started = Queue.new
    release_mutation = Queue.new
    revocation_started = Queue.new

    mutation_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        actor = User.find(user.id)
        thread_conversation = Conversation.find(conversation.id)
        Logic::Conversations::Policy.new(conversation: thread_conversation, actor:, context: actor.main_context).with_access do
          mutation_started << true
          wait_for_signal(release_mutation, description: "the authorized conversation mutation release")
          ConversationParticipant.find(participant_id).update!(archived_at: Time.current)
        end
      end
    end
    wait_for_signal(mutation_started, description: "the authorized conversation mutation to start")

    revocation_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        revocation_started << true
        record = Friendship.find(friendship.id)
        record.with_lock { record.update_columns(state: "blocked") }
      end
    end
    wait_for_signal(revocation_started, description: "the friendship revocation to start")
    release_mutation << true
    thread_value(mutation_thread, description: "the authorized conversation mutation")
    thread_value(revocation_thread, description: "the friendship revocation")

    expect(ConversationParticipant.find(participant_id)).to be_archived
    expect(Friendship.find(friendship.id)).to be_blocked_state
  ensure
    friendship&.update_columns(state: "accepted")
    Conversation.where(friendship_id: friendship&.id).destroy_all
    friendship&.destroy!
  end
end
