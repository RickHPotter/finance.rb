# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryTransactable, type: :concern do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }

  let(:category) { create(:category, :random, user:, built_in: true) }
  let(:custom_category) { create(:category, :random, user:, built_in: false) }

  let(:card_transaction) do
    create(:card_transaction, :random, user:, user_card:, category_transactions: [
             build(:category_transaction, :random, category:, transactable: nil),
             build(:category_transaction, :random, category: custom_category, transactable: nil)
           ])
  end

  describe "[ public class methods ]" do
    it "#custom_categories" do
      expect(card_transaction.custom_categories).to include(custom_category)
      expect(card_transaction.custom_categories).not_to include(category)
    end

    it "#built_in_category_transactions_by" do
      expect(card_transaction.built_in_category_transactions_by.map(&:category)).to include(category)
    end

    it "#built_in_categories_by" do
      expect(card_transaction.built_in_categories_by).to include(category)
    end
  end
end
