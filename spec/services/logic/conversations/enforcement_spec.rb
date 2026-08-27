# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Canonical conversation enforcement", type: :service do
  let(:actionable_producers) do
    %w[
      app/models/concerns/friend_notifiable.rb
      app/services/logic/shared_return_structure_update_message_service.rb
      app/services/logic/shared_return_destroy_message_service.rb
      app/services/logic/shared_paid_state_sync_service.rb
      app/controllers/cash_transactions_controller.rb
    ]
  end

  it "removes legacy model creation and participant nesting APIs" do
    expect(Conversation).not_to respond_to(
      :fast_create,
      :find_or_create_human_between!,
      :find_or_create_assistant_between!,
      :resolve_between!,
      :for_users
    )
    expect(Conversation.nested_attributes_options).not_to have_key(:conversation_participants)
  end

  it "keeps direct conversation persistence inside the canonical resolver" do
    offenders = application_ruby_paths.filter_map do |path|
      relative_path = relative(path)
      source = File.read(path)
      forbidden = source.match?(/Conversation\.(?:create!?|new|insert_all!?|upsert_all|fast_create|find_or_create_\w+_between!|for_users)\b/) ||
                  (source.match?(/conversation_participants\.(?:build|create!?)/) && relative_path != resolver_path)
      relative_path if forbidden && relative_path != resolver_path
    end

    expect(offenders).to be_empty
  end

  it "keeps every established actionable producer on the canonical resolver" do
    actionable_producers.each do |relative_path|
      expect(Rails.root.join(relative_path).read).to include("Logic::Conversations::Resolve.call"), "#{relative_path} bypasses the canonical resolver"
    end
  end

  it "keeps profile-first identity while restricting entity avatars to human conversation cards" do
    index_source = Rails.root.join("app/views/conversations/index.rb").read
    other_source = conversation_view_paths.reject { |path| path.end_with?("/index.rb") }.sort.map { |path| File.read(path) }.join("\n")
    source = [ index_source, other_source ].join("\n")

    expect(source).to include("ProfileAvatar")
    expect(source).not_to match(/\bEntity\b|entity_name/)
    expect(index_source).to include("conversation.human?", "current_user.entities", "entity.avatar_name")
    expect(other_source).not_to match(/avatar_name|\.entities\b/)
  end

  it "keeps conversation and message copy structurally complete in English and Portuguese" do
    conversation_copy = locale_tree("config/locales/models/conversations.yml")
    message_copy = locale_tree("config/locales/models/messages.yml")
    controller_copy = locale_tree("config/locales/controllers/messages.yml")

    expect(locale_keys(conversation_copy, "activerecord", "attributes", "conversation", locale: "en"))
      .to eq(locale_keys(conversation_copy, "activerecord", "attributes", "conversation", locale: "pt-BR"))
    expect(locale_keys(message_copy, "activerecord", "attributes", "message", locale: "en"))
      .to eq(locale_keys(message_copy, "activerecord", "attributes", "message", locale: "pt-BR"))
    expect(locale_keys(controller_copy, "messages", locale: "en")).to eq(locale_keys(controller_copy, "messages", locale: "pt-BR"))
  end

  it "passes the clean deployment inventory for canonical test data" do
    user = create(:user, :random)
    friend = create(:user, :random)
    create(:friendship, :accepted, user:, friend:)
    resolve_human_conversation(user, friend)

    expect(Logic::Conversations::Inventory.new.call).to be_clean
  end

  it "enforces canonical identity, classifications, and the exact participant pair in PostgreSQL" do
    user = create(:user, :random)
    friend = create(:user, :random)
    create(:friendship, :accepted, user:, friend:)
    conversation = resolve_human_conversation(user, friend)
    message = conversation.messages.create!(user:, body: "Canonical message")

    expect_database_rejection { Conversation.where(id: conversation.id).update_all(kind: "group") }
    expect_database_rejection { Message.where(id: message.id).update_all(kind: "unknown") }
    expect_database_rejection { Message.where(id: message.id).update_all(action_state: "pending") }

    expect_database_rejection do
      conversation.participant_for!(friend).delete
      ApplicationRecord.connection.execute("SET CONSTRAINTS conversation_participants_canonical_pair IMMEDIATE")
    end

    historical_conversation = Conversation.create!(kind: :human)
    expect_database_rejection do
      ConversationParticipant.find_by!(conversation:, user: friend).update_column(:conversation_id, historical_conversation.id)
      ApplicationRecord.connection.execute("SET CONSTRAINTS conversation_participants_canonical_pair IMMEDIATE")
    end
  end

  def resolver_path
    "app/services/logic/conversations/resolve.rb"
  end

  def application_ruby_paths
    Dir[Rails.root.join("app/**/*.rb")]
  end

  def conversation_view_paths
    Dir[Rails.root.join("app/views/conversations/*.rb")]
  end

  def relative(path)
    Pathname(path).relative_path_from(Rails.root).to_s
  end

  def locale_tree(relative_path)
    YAML.safe_load_file(Rails.root.join(relative_path))
  end

  def locale_keys(tree, *path, locale:)
    path.reduce(tree.fetch(locale)) { |branch, key| branch.fetch(key) }.keys.sort
  end

  def expect_database_rejection(&)
    expect do
      ApplicationRecord.transaction(requires_new: true, &)
    end.to raise_error(ActiveRecord::StatementInvalid)
  end
end
