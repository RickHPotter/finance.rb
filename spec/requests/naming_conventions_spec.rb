# frozen_string_literal: true

require "rails_helper"

RSpec.describe "NamingConventions", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #preview ]" do
    it "renders successfully" do
      post preview_naming_convention_path

      expect(response).to have_http_status(:success)
    end

    it "scopes the naming run to the current context only" do
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      create(:cash_transaction, user:, context: user.main_context, user_bank_account:, description: "MAIN")
      derived_context = create(:context, user:, name: "Naming Isolation", source_context: user.main_context)
      derived_transaction = create(:cash_transaction, user:, context: derived_context, user_bank_account:, description: "DERIVED")
      naming_service = instance_double(Linter::NamingService, call: [])

      patch switch_context_path(derived_context)

      expect(Linter::NamingService).to receive(:new) do |**kwargs|
        expect(kwargs[:cash_transactions].except(:includes).ids).to eq([ derived_transaction.id ])
        expect(kwargs[:user]).to eq(user)
        expect(kwargs[:dry_run]).to be(true)
        naming_service
      end

      post preview_naming_convention_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #update ]" do
    it "renders successfully as turbo stream" do
      patch naming_convention_path, headers: turbo_stream_headers

      expect(response).to have_http_status(:success)
    end
  end
end
