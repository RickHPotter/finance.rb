# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversation policy revocation concurrency" do
  self.use_transactional_tests = false

  it "serializes friendship revocation after an authorized mutation" do
    user = create(:user, :random)
    friend = create(:user, :random)
    friendship = create(:friendship, :accepted, user:, friend:)
    conversation = Conversation.find_or_create_human_between!(user, friend)
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
          release_mutation.pop
          ConversationParticipant.find(participant_id).update!(archived_at: Time.current)
        end
      end
    end
    mutation_started.pop

    revocation_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        revocation_started << true
        record = Friendship.find(friendship.id)
        record.with_lock { record.update_columns(state: "blocked") }
      end
    end
    revocation_started.pop
    release_mutation << true
    mutation_thread.value
    revocation_thread.value

    expect(ConversationParticipant.find(participant_id)).to be_archived
    expect(Friendship.find(friendship.id)).to be_blocked_state
  ensure
    friendship&.update_columns(state: "accepted")
    Conversation.where(friendship_id: friendship&.id).destroy_all
    friendship&.destroy!
  end
end
