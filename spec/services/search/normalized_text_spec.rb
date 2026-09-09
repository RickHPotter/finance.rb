# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::NormalizedText do
  describe ".apply" do
    let(:user) { create(:user, :random) }

    it "matches text without regard to accents, case, or repeated whitespace" do
      matching = create(:category, :random, user:, category_name: "CRÍSTIAN   PENS")
      create(:category, :random, user:, category_name: "ANOTHER CATEGORY")

      result = described_class.apply(user.categories, "  cristian pens  ", "categories.category_name")

      expect(result).to contain_exactly(matching)
    end

    it "searches across each configured text or numeric column" do
      bank = create(:bank, :random)
      by_name = create(:user_bank_account, :random, user:, bank:, user_bank_account_name: "POUPÁNÇA ESPECIAL")
      by_agency = create(:user_bank_account, :random, user:, bank:, user_bank_account_name: "OTHER", agency_number: 12_345)

      columns = %w[user_bank_accounts.user_bank_account_name user_bank_accounts.agency_number user_bank_accounts.account_number]

      expect(described_class.apply(user.user_bank_accounts, "poupanca", *columns)).to contain_exactly(by_name)
      expect(described_class.apply(user.user_bank_accounts, "12345", *columns)).to contain_exactly(by_agency)
    end

    it "treats SQL wildcard characters as literal search text" do
      literal = create(:category, :random, user:, category_name: "RATE 100%_FIXED")
      create(:category, :random, user:, category_name: "RATE 100X-FIXED")

      result = described_class.apply(user.categories, "%_", "categories.category_name")

      expect(result).to contain_exactly(literal)
    end

    it "does not add a condition for blank text" do
      relation = user.categories.where(active: true)

      expect(described_class.apply(relation, " \t ", "categories.category_name").to_sql).to eq(relation.to_sql)
    end

    it "rejects dynamic SQL expressions as columns" do
      expect do
        described_class.apply(user.categories, "anything", "category_name) OR TRUE")
      end.to raise_error(ArgumentError, /Invalid search column/)
    end
  end
end
