# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Account and card navigation state" do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }

  it "retains account and card search/status state" do
    account_state = Navigation::UserBankAccounts.new(
      raw: "/user_bank_accounts?search_term=pix&user_bank_account[status][]=active",
      fallback: "/user_bank_accounts",
      current_user: user
    )
    card_state = Navigation::UserCards.new(
      raw: "/user_cards?search_term=visa&user_card[status][]=inactive",
      fallback: "/user_cards",
      current_user: user
    )

    expect(account_state.destination).to eq("/user_bank_accounts?search_term=pix&user_bank_account%5Bstatus%5D%5B%5D=active")
    expect(card_state.destination).to eq("/user_cards?search_term=visa&user_card%5Bstatus%5D%5B%5D=inactive")
  end

  it "rejects foreign owned identifiers and paths outside each resource" do
    foreign_account = create(:user_bank_account, :random, user: other_user)
    foreign_card = create(:user_card, :random, user: other_user)

    account_state = Navigation::UserBankAccounts.new(
      raw: "/user_bank_accounts?user_bank_account[id]=#{foreign_account.id}",
      fallback: "/user_bank_accounts",
      current_user: user
    )
    card_state = Navigation::UserCards.new(
      raw: "/user_cards?user_card[id]=#{foreign_card.id}",
      fallback: "/user_cards",
      current_user: user
    )
    wrong_path_state = Navigation::UserBankAccounts.new(raw: "/user_cards", fallback: "/user_bank_accounts", current_user: user)

    expect(account_state.destination).to eq("/user_bank_accounts")
    expect(account_state.rejected_reason).to eq(:foreign_identifier)
    expect(card_state.destination).to eq("/user_cards")
    expect(card_state.rejected_reason).to eq(:foreign_identifier)
    expect(wrong_path_state.destination).to eq("/user_bank_accounts")
    expect(wrong_path_state.rejected_reason).to eq(:path_not_allowed)
  end
end
