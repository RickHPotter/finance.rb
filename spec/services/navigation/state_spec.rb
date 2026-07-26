# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation::State do
  def build_state(raw)
    described_class.new(
      raw:,
      fallback: "/cash_transactions",
      allowed_paths: [ "/cash_transactions", "/budgets" ],
      query_schema: {
        search_term: :scalar,
        active_month_years: :scalar_or_array,
        cash_transaction: {
          user_bank_account_id: :scalar_or_array,
          cash_installment_ids: :array
        }
      },
      id_scopes: {
        "cash_transaction.user_bank_account_id" => lambda { |ids|
          ids.all? { |id| id.in?(%w[11 12]) }
        }
      }
    )
  end

  describe "#destination" do
    it "accepts an allowlisted relative path and known query state" do
      state = build_state("/cash_transactions?search_term=rent&active_month_years=202607")

      expect(state.destination).to eq("/cash_transactions?active_month_years=202607&search_term=rent")
      expect(state).to be_accepted
      expect(state.rejected_reason).to be_nil
    end

    it "retains bounded nested arrays" do
      state = build_state("/cash_transactions?cash_transaction[user_bank_account_id][]=11&cash_transaction[cash_installment_ids][]=21")

      expect(state.destination).to eq(
        "/cash_transactions?cash_transaction%5Bcash_installment_ids%5D%5B%5D=21&cash_transaction%5Buser_bank_account_id%5D%5B%5D=11"
      )
    end

    it "strips unknown query keys at every level" do
      state = build_state("/cash_transactions?admin=1&cash_transaction[user_bank_account_id]=11&cash_transaction[price]=999")

      expect(state.destination).to eq("/cash_transactions?cash_transaction%5Buser_bank_account_id%5D=11")
      expect(state).to be_accepted
    end

    it "rejects absolute, protocol-relative, and malformed destinations" do
      [
        "https://evil.example/cash_transactions",
        "//evil.example/cash_transactions",
        "/cash_transactions\\@evil.example",
        "%%%not-a-uri"
      ].each do |unsafe_raw|
        state = build_state(unsafe_raw)

        expect(state.destination).to eq("/cash_transactions")
        expect(state).not_to be_accepted
      end
    end

    it "rejects paths outside the route allowlist" do
      state = build_state("/users/sign_out")

      expect(state.destination).to eq("/cash_transactions")
      expect(state.rejected_reason).to eq(:path_not_allowed)
    end

    it "rejects foreign and malformed owned identifiers" do
      [
        "/cash_transactions?cash_transaction[user_bank_account_id]=999",
        "/cash_transactions?cash_transaction[user_bank_account_id]=not-an-id"
      ].each do |unsafe_raw|
        state = build_state(unsafe_raw)

        expect(state.destination).to eq("/cash_transactions")
        expect(state.rejected_reason).to eq(:foreign_identifier)
      end
    end

    it "rejects oversized arrays and scalar values" do
      array_state = build_state(
        "/cash_transactions?cash_transaction[cash_installment_ids][]=#{Array.new(51, 1).join('&cash_transaction[cash_installment_ids][]=')}"
      )
      scalar_state = build_state("/cash_transactions?search_term=#{'a' * 257}")

      expect(array_state.rejected_reason).to eq(:invalid_query_shape)
      expect(scalar_state.rejected_reason).to eq(:invalid_query_shape)
    end

    it "uses the canonical fallback when state is absent" do
      state = build_state(nil)

      expect(state.destination).to eq("/cash_transactions")
      expect(state.rejected_reason).to eq(:missing)
    end
  end

  describe "configuration" do
    it "rejects non-local fallback and query-bearing allowlist paths" do
      expect do
        described_class.new(raw: nil, fallback: "https://evil.example", allowed_paths: [ "/cash_transactions" ])
      end.to raise_error(ArgumentError, /local absolute paths/)

      expect do
        described_class.new(raw: nil, fallback: "/cash_transactions", allowed_paths: [ "/cash_transactions?admin=1" ])
      end.to raise_error(ArgumentError, /cannot include query state/)
    end
  end
end
