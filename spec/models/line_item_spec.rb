# frozen_string_literal: true

require "rails_helper"

RSpec.describe LineItem do
  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:leaf_category) { create(:category, user:) }
  let(:parent_category) do
    parent = create(:category, :parent_category, user:)
    create(:category, :child_category, parent_category: parent, user:)
    parent
  end
  let(:entity) { create(:entity, user:) }
  let(:cash_transaction) { create(:cash_transaction, user:, context:, price: 100_00) }
  let(:card_transaction) { create(:card_transaction, user:, context:, price: -100_00) }

  describe "validations" do
    it "is valid with valid attributes" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Organic Apples",
        price: 50_00,
        category: leaf_category
      )

      expect(line_item).to be_valid
    end

    it "requires description" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "",
        price: 50_00,
        category: leaf_category
      )

      expect(line_item).not_to be_valid
      expect(line_item.errors[:description]).to include("can't be blank")
    end

    it "requires price" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Apples",
        price: nil,
        category: leaf_category
      )

      expect(line_item).not_to be_valid
      expect(line_item.errors[:price]).to include("can't be blank")
    end

    it "rejects zero price" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Apples",
        price: 0,
        category: leaf_category
      )

      expect(line_item).not_to be_valid
      expect(line_item.errors[:price]).to be_present
    end

    it "requires category" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Apples",
        price: 50_00
      )

      expect(line_item).not_to be_valid
      expect(line_item.errors[:category_id]).to be_present
    end

    it "rejects parent categories" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Apples",
        price: 50_00,
        category: parent_category
      )

      expect(line_item).not_to be_valid
      expect(line_item.errors[:category_id]).to include(
        I18n.t("activerecord.errors.models.line_item.attributes.category_id.must_be_leaf_category")
      )
    end

    it "accepts subcategories" do
      subcategory = create(:category, :child_category, parent_category:, user:, category_name: "BOOKS")
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Apples",
        price: 50_00,
        category: subcategory
      )

      expect(line_item).to be_valid
    end

    describe "sign matching" do
      it "rejects negative price for positive transaction" do
        line_item = described_class.new(
          transactable: cash_transaction,
          description: "Apples",
          price: -50_00,
          category: leaf_category
        )

        expect(line_item).not_to be_valid
        expect(line_item.errors[:price]).to include(
          I18n.t("activerecord.errors.models.line_item.attributes.price.must_be_positive_to_match_transaction")
        )
      end

      it "rejects positive price for negative card transaction" do
        line_item = described_class.new(
          transactable: card_transaction,
          description: "Apples",
          price: 50_00,
          category: leaf_category
        )

        expect(line_item).not_to be_valid
        expect(line_item.errors[:price]).to include(
          I18n.t("activerecord.errors.models.line_item.attributes.price.must_be_negative_to_match_transaction")
        )
      end

      it "accepts negative price for negative card transaction" do
        line_item = described_class.new(
          transactable: card_transaction,
          description: "Apples",
          price: -50_00,
          category: leaf_category
        )

        expect(line_item).to be_valid
      end
    end
  end

  describe "virtual accessors" do
    it "manages category_transactions through category_id" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Test",
        price: 10_00,
        category_id: leaf_category.id
      )

      expect(line_item.category).to eq(leaf_category)
      expect(line_item.category_transactions.size).to eq(1)
      expect(line_item.category_transactions.first.category_id).to eq(leaf_category.id)
    end

    it "manages entity_transactions through entity_id" do
      line_item = described_class.new(
        transactable: cash_transaction,
        description: "Test",
        price: 10_00,
        category: leaf_category,
        entity_id: entity.id
      )

      expect(line_item.entity).to eq(entity)
      expect(line_item.entity_transactions.size).to eq(1)
      expect(line_item.entity_transactions.first.entity_id).to eq(entity.id)
      expect(line_item.entity_transactions.first.price).to eq(10_00)
    end
  end

  describe "attachments" do
    let(:line_item) do
      described_class.new(
        transactable: cash_transaction,
        description: "Organic Apples",
        price: 50_00,
        category: leaf_category
      )
    end

    it "has many attached receipts" do
      expect(described_class.reflect_on_attachment(:receipts)).not_to be_nil
    end

    it "accepts an allowed attachment at exactly 10 MiB" do
      line_item.receipts.attach(io: StringIO.new("a" * 10.megabytes), filename: "receipt.pdf", content_type: "application/pdf")

      expect(line_item).to be_valid
    end

    it "rejects an unsupported content type" do
      line_item.receipts.attach(io: StringIO.new("binary"), filename: "script.exe", content_type: "application/x-msdownload")

      expect(line_item).not_to be_valid
      expect(line_item.errors[:receipts]).to be_present
    end

    it "rejects a file larger than 10 MiB" do
      line_item.receipts.attach(io: StringIO.new("a" * (10.megabytes + 1)), filename: "large.pdf", content_type: "application/pdf")

      expect(line_item).not_to be_valid
      expect(line_item.errors[:receipts]).to be_present
    end

    it "rejects a sixth attachment" do
      6.times do |index|
        line_item.receipts.attach(io: StringIO.new("data"), filename: "receipt_#{index}.pdf", content_type: "application/pdf")
      end

      expect(line_item).not_to be_valid
      expect(line_item.errors[:receipts]).to be_present
    end
  end

  describe "delegations" do
    it "delegates user and context to transactable" do
      line_item = described_class.new(transactable: cash_transaction)

      expect(line_item.user).to eq(cash_transaction.user)
      expect(line_item.context).to eq(cash_transaction.context)
    end
  end
end

# == Schema Information
#
# Table name: line_items
# Database name: primary
#
#  id                :bigint           not null, primary key
#  comment           :text
#  description       :string           not null
#  price             :integer          default(0), not null
#  transactable_type :string           not null, indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  transactable_id   :bigint           not null, indexed => [transactable_type]
#
# Indexes
#
#  index_line_items_on_transactable_type_and_transactable_id  (transactable_type,transactable_id)
#
