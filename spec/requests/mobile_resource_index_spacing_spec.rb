# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mobile resource index spacing", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "keeps account, card, category, and entity cards aligned with their filter boxes" do
    resources = [
      [ user_bank_accounts_path, create(:user_bank_account, :random, user:, bank: create(:bank, :random)) ],
      [ user_cards_path, create(:user_card, :random, user:, card: create(:card, :random)) ],
      [ categories_path, create(:category, :random, user:) ],
      [ entities_path, create(:entity, :random, user:) ]
    ]

    resources.each do |path, record|
      get path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)" }

      document = Nokogiri::HTML.parse(response.body)
      card = document.at_css("[data-id='#{record.id}'][data-datatable-target='row']")
      expect(document.at_css("div.mb-6.grid.grid-cols-1")).to be_present
      expect(card).to be_present
      expect(card["class"].split).to include("my-3")
      expect(card["class"].split).not_to include("mx-2")
    end
  end

  it "places transaction actions first and left-aligns the entity merge action" do
    resources = [
      [ user_bank_accounts_path, create(:user_bank_account, :random, user:, bank: create(:bank, :random)), 1 ],
      [ user_cards_path, create(:user_card, :random, user:, card: create(:card, :random)), 1 ],
      [ entities_path, create(:entity, :random, user:), 2 ]
    ]

    resources.each do |path, record, transaction_actions_count|
      get path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)" }

      card = response.parsed_body.at_css("[data-id='#{record.id}'][data-datatable-target='row']")
      rows = card.css("[data-mobile-action-row]")
      expect(rows.first["data-mobile-action-row"]).to eq("transactions")
      expect(rows.first.css("a").size).to eq(transaction_actions_count)

      if record.is_a?(Entity)
        expect(rows.map { |row| row["data-mobile-action-row"] }).to eq(%w[transactions primary])
        expect(rows.last.at_css("button")["class"].split).to include("text-left")
      else
        expect(rows.size).to eq(1)
        expect(rows.first.at_css("a")["class"].split).to include("w-full")
      end
    end
  end
end
