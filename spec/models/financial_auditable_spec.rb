# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinancialAuditable, type: :model do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_bank_account) { create(:user_bank_account, :random, user:) }

  def build_cash_transaction
    build(
      :cash_transaction,
      user:,
      context:,
      user_bank_account:,
      description: "Audited cash transaction",
      price: 5_000,
      date: Date.new(2026, 7, 19),
      month: 7,
      year: 2026
    )
  end

  it "records a transaction graph under one owned operation" do
    transaction = build_cash_transaction
    transaction.category_transactions = [ build(:category_transaction, transactable: nil, category: create(:category, :random, user:)) ]
    transaction.entity_transactions = [
      build(
        :entity_transaction,
        transactable: nil,
        entity: create(:entity, :random, user:),
        is_payer: false,
        price: 0,
        price_to_be_returned: 0,
        exchanges: []
      )
    ]

    Audit::Operation.run(actor: user, context:, source: :web) { transaction.save! }

    versions = AuditVersion.where(operation_id: AuditOperation.last.id)
    expect(versions.pluck(:item_type)).to include("CashTransaction", "Installment", "CategoryTransaction", "EntityTransaction")
    expect(versions.pluck(:owner_id).uniq).to eq([ user.id ])
    expect(versions.pluck(:context_id).uniq).to eq([ context.id ])
    expect(versions.pluck(:mutation_source).uniq).to eq([ "web" ])

    installment_version = versions.find_by!(item_type: "Installment")
    expect(installment_version.item_subtype).to eq("CashInstallment")
  end

  it "excludes cache-only fields without suppressing canonical changes" do
    transaction = PaperTrail.request(enabled: false) { build_cash_transaction.tap(&:save!) }

    Audit::Operation.run(actor: user, context:, source: :web) do
      Audit::BulkMutation.update_columns!(transaction, cash_installments_count: 9)
      Audit::BulkMutation.update_columns!(transaction, description: "Corrected description", cash_installments_count: 10)
    end

    versions = AuditVersion.where(item: transaction)
    expect(versions.size).to eq(1)
    expect(versions.first.object_changes).to eq("description" => [ "Audited cash transaction", "Corrected description" ])
    expect(versions.first.object).not_to include("cash_installments_count", "created_at", "updated_at")
  end

  it "captures before-state for callback-bypassing bulk deletion" do
    transaction = PaperTrail.request(enabled: false) { build_cash_transaction.tap(&:save!) }
    installment_ids = transaction.cash_installments.ids

    Audit::Operation.run(actor: user, context:, source: :admin_repair) do
      Audit::BulkMutation.delete_all!(transaction.cash_installments)
    end

    versions = AuditVersion.where(item_type: "Installment", item_id: installment_ids, event: :destroy)
    expect(versions.count).to eq(installment_ids.count)
    expect(versions.first).to have_attributes(owner_id: user.id, context_id: context.id, mutation_source: "admin_repair")
    expect(versions.first.object).to include("cash_transaction_id" => transaction.id, "price" => 5_000)
    expect(Installment.where(id: installment_ids)).to be_empty
  end

  it "retains the complete dependent-destroy graph after live rows are gone" do
    transaction = PaperTrail.request(enabled: false) do
      build_cash_transaction.tap do |record|
        record.category_transactions = [ build(:category_transaction, transactable: nil, category: create(:category, :random, user:)) ]
        record.entity_transactions = [
          build(
            :entity_transaction,
            transactable: nil,
            entity: create(:entity, :random, user:),
            is_payer: false,
            price: 0,
            price_to_be_returned: 0,
            exchanges: []
          )
        ]
        record.save!
      end
    end
    graph_ids = {
      "CashTransaction" => [ transaction.id ],
      "Installment" => transaction.cash_installments.ids,
      "CategoryTransaction" => transaction.category_transactions.ids,
      "EntityTransaction" => transaction.entity_transactions.ids
    }

    Audit::Operation.run(actor: user, context:, source: :web) { transaction.destroy! }

    destroy_versions = AuditVersion.where(operation_id: AuditOperation.last.id, event: :destroy)
    graph_ids.each do |item_type, item_ids|
      expect(destroy_versions.where(item_type:, item_id: item_ids).count).to eq(item_ids.count)
    end
    expect(CashTransaction.where(id: graph_ids.fetch("CashTransaction"))).to be_empty
    expect(Installment.where(id: graph_ids.fetch("Installment"))).to be_empty
    expect(CategoryTransaction.where(id: graph_ids.fetch("CategoryTransaction"))).to be_empty
    expect(EntityTransaction.where(id: graph_ids.fetch("EntityTransaction"))).to be_empty
  end

  it "does not retain versions when paid-history protection rejects destruction" do
    transaction = PaperTrail.request(enabled: false) { build_cash_transaction.tap(&:save!) }
    transaction.cash_installments.first.update_column(:paid, true)
    version_count = AuditVersion.count

    result = Audit::Operation.run(actor: user, context:, source: :web) { transaction.destroy }

    expect(result).to be(false)
    expect(transaction.errors).to include(:base)
    expect(AuditVersion.count).to eq(version_count)
  end

  it "uses one operation and distinct immediate sources for a card exchange projection" do
    user_card = create(:user_card, :random, user:)
    exchange_category = user.built_in_category("EXCHANGE")
    entity = create(:entity, :random, user:)
    transaction = build(
      :card_transaction,
      :random,
      user:,
      context:,
      user_card:,
      price: -180,
      date: Time.zone.today,
      card_installments: build_list(:card_installment, 2, price: -90) { |installment, index| installment.number = index + 1 },
      category_transactions: [ build(:category_transaction, category: exchange_category, transactable: nil) ],
      entity_transactions: [
        build(
          :entity_transaction,
          entity:,
          transactable: nil,
          price: 180,
          is_payer: true,
          exchanges: build_list(:exchange, 2, exchange_type: :monetary, price: 90, entity_transaction: nil) do |exchange, index|
            exchange.number = index + 1
            exchange.date = Time.zone.today + index.months
          end
        )
      ]
    )

    Audit::Operation.run(actor: user, context:, source: :web) { transaction.save! }

    root_version = AuditVersion.find_by!(item: transaction, event: :create)
    projection_versions = AuditVersion.where(operation_id: root_version.operation_id, item_type: "CashTransaction", mutation_source: :projection_sync)
    expect(root_version.mutation_source).to eq("web")
    expect(projection_versions).to exist
    expect(projection_versions.pluck(:operation_id).uniq).to eq([ root_version.operation_id ])
  end
end
