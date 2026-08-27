# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation::ContextSwitch do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }

  def navigation(raw)
    described_class.new(raw:, fallback: "/", current_user: user, current_context: context)
  end

  it "retains allowlisted index state and maps member forms to their safe indexes" do
    account = create(:user_bank_account, :random, user:)

    expect(navigation("/balances?tab=monthly_analysis&month=2026-05").destination)
      .to eq("/balances?month=2026-05&tab=monthly_analysis")
    expect(navigation("/user_bank_accounts?search_term=pix&user_bank_account[status][]=active").destination)
      .to eq("/user_bank_accounts?search_term=pix&user_bank_account%5Bstatus%5D%5B%5D=active")
    expect(navigation("/user_bank_accounts/#{account.id}/edit").destination).to eq("/user_bank_accounts")
  end

  it "maps conversation details to the conversation index with a redirect signal" do
    other_user = create(:user, :random)
    create(:friendship, :accepted, user:, friend: other_user)
    conversation = resolve_human_conversation(user, other_user)
    state = navigation("/conversations/#{conversation.public_id}")

    expect(state.destination).to eq("/conversations")
    expect(state).to be_redirected_conversation
  end

  it "rejects unsafe and unknown destinations" do
    expect(navigation("https://evil.example/balances").destination).to eq("/")
    expect(navigation("//evil.example/balances").destination).to eq("/")
    expect(navigation("/admin/unknown").destination).to eq("/")
  end
end
