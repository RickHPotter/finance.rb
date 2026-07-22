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

  it "enables the complete initial model scope with explicit derived-field exclusions" do
    expected_skips = {
      CashTransaction => %w[cash_installments_count],
      CardTransaction => %w[card_installments_count],
      Installment => %w[balance order_id cash_installments_count card_installments_count],
      CategoryTransaction => [],
      EntityTransaction => %w[exchanges_count],
      Exchange => %w[exchanges_count],
      Reference => [],
      UserCard => %w[card_transactions_count card_transactions_total],
      UserBankAccount => %w[balance cash_transactions_count cash_transactions_total],
      Budget => %w[balance order_id remaining_value],
      Subscription => %w[card_transactions_count cash_transactions_count price],
      Investment => [],
      PiggyBank => []
    }

    expected_skips.each do |model, model_skips|
      expect(Audit::BulkMutation.audited_model?(model)).to be(true)
      expect(model.paper_trail_options.fetch(:skip)).to contain_exactly("created_at", "updated_at", *model_skips)
    end
  end

  it "retains account history without a selected context" do
    account = build(:user_bank_account, :random, user:)

    Audit::Operation.run(actor: user, context:, source: :web) do
      account.save!
      account.update!(active: false)
      account.destroy!
    end

    versions = AuditVersion.where(item_type: "UserBankAccount", item_id: account.id).order(:id)
    expect(versions.pluck(:event)).to eq(%w[create update destroy])
    expect(versions.pluck(:owner_id).uniq).to eq([ user.id ])
    expect(versions.pluck(:context_id).uniq).to eq([ nil ])
    expect(versions.last.metadata).to eq("bank_id" => account.bank_id)
  end

  it "rolls back a business mutation when its audit payload exceeds the limit" do
    account = PaperTrail.request(enabled: false) { create(:user_bank_account, :random, user:) }
    original_name = account.user_bank_account_name

    expect do
      Audit::Operation.run(actor: user, context:, source: :web) do
        account.update!(user_bank_account_name: "a" * 300.kilobytes)
      end
    end.to raise_error(ActiveRecord::RecordInvalid, /Object changes/)

    expect(account.reload.user_bank_account_name).to eq(original_name)
    expect(AuditVersion.where(item: account)).to be_empty
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

    root_version = AuditVersion.find_by!(item: transaction, event: :create)
    versions = AuditVersion.where(operation_id: root_version.operation_id)
    expect(versions.pluck(:item_type)).to include("CashTransaction", "Installment", "CategoryTransaction", "EntityTransaction")
    expect(versions.pluck(:owner_id).uniq).to eq([ user.id ])
    expect(versions.pluck(:context_id).uniq).to eq([ context.id ])
    expect(versions.pluck(:mutation_source).uniq).to eq([ "web" ])

    installment_version = versions.find_by!(item_type: "Installment")
    expect(installment_version.item_subtype).to eq("CashInstallment")
    expect(installment_version.metadata).to eq("cash_transaction_id" => transaction.id)
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

  it "records one version for one model event without recursively auditing audit rows" do
    transaction = PaperTrail.request(enabled: false) { build_cash_transaction.tap(&:save!) }
    operation = nil

    Audit::Operation.run(actor: user, context:, source: :web) do
      transaction.update!(description: "One audited correction")
      operation = Audit::Operation.ensure_persisted!
    end

    versions = operation.audit_versions
    expect(versions.where(item_type: "CashTransaction", item_id: transaction.id, event: :update).count).to eq(1)
    expect(versions.where(item_type: %w[AuditOperation AuditVersion])).to be_empty
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

    root_destroy = AuditVersion.find_by!(item_type: "CashTransaction", item_id: transaction.id, event: :destroy)
    destroy_versions = AuditVersion.where(operation_id: root_destroy.operation_id, event: :destroy)
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
