# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit operation context", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "wraps mutating requests with actor, context, request ID, and web source" do
    expect(Audit::Operation).to receive(:run).with(
      actor: user,
      context: user.main_context,
      source: :web,
      request_id: kind_of(String),
      parent_operation_id: nil
    ).and_call_original

    expect do
      patch switch_context_path(user.main_context)
    end.not_to change(AuditOperation, :count)

    expect(response).to redirect_to(root_path)
    expect(Audit::Current).not_to be_active
  end

  it "does not establish audit context for read requests" do
    expect(Audit::Operation).not_to receive(:run)

    get contexts_path

    expect(response).to have_http_status(:ok)
  end

  it "does not leak actor or context between sequential mutating requests" do
    second_user = create(:user, :random)
    observed_boundaries = []
    allow(Audit::Operation).to receive(:run).and_wrap_original do |method, **attributes, &block|
      observed_boundaries << attributes.slice(:actor, :context, :source)
      method.call(**attributes, &block)
    end

    patch switch_context_path(user.main_context)
    expect(Audit::Current).not_to be_active
    sign_out user
    sign_in second_user
    patch switch_context_path(second_user.main_context)

    expect(observed_boundaries).to eq(
      [
        { actor: user, context: user.main_context, source: :web },
        { actor: second_user, context: second_user.main_context, source: :web }
      ]
    )
    expect(Audit::Current).not_to be_active
    expect(PaperTrail.request.whodunnit).to be_nil
  end

  it "selects specialized root sources for actionable messages and admin repairs" do
    messages_controller = MessagesController.new
    allow(messages_controller).to receive(:action_name).and_return("apply")

    expect(messages_controller.send(:audit_operation_source)).to eq(:actionable_message)
    expect(Admin::SettingsController.new.send(:audit_operation_source)).to eq(:admin_repair)
  end

  it "links actionable message work to the latest audited sender operation" do
    sender = create(:user, :random)
    reference = create(:cash_transaction, user: sender, context: sender.main_context)
    conversation = Conversation.find_or_create_assistant_between!(user, sender)
    parent_operation = nil
    message = nil

    Audit::Operation.run(actor: sender, context: sender.main_context, source: :web) do
      parent_operation = Audit::Operation.ensure_persisted!
      message = conversation.messages.create!(
        user: sender,
        body: "notification:paid_state",
        reference_transactable: reference,
        headers: {
          version: "message_paid_state_v1",
          event: { action: "paid", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: {} }
        }.to_json
      )
    end

    expect(message.audit_operation_id).to eq(parent_operation.id)

    expect(Audit::Operation).to receive(:run).with(
      actor: user,
      context: user.main_context,
      source: :actionable_message,
      request_id: kind_of(String),
      parent_operation_id: parent_operation.id
    ).and_call_original

    patch apply_conversation_message_path(conversation, message), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(message.reload.applied_at).to be_present
  end
end
