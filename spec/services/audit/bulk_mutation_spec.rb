# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::BulkMutation do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:entity) { create(:entity, :random, user:) }
  let(:transaction) do
    PaperTrail.request(enabled: false) do
      create(:cash_transaction, :random, user:, context:, user_bank_account: create(:user_bank_account, :random, user:))
    end
  end

  it "records a direct insert while preserving callback-bypass semantics" do
    entity_transaction = PaperTrail.request(enabled: false) do
      create(:entity_transaction, transactable: transaction, entity:, price: 25, price_to_be_returned: 25, is_payer: true, exchanges: [])
    end
    now = Time.current

    exchange = Audit::Operation.run(actor: user, context:, source: :admin_repair) do
      described_class.insert!(
        Exchange,
        entity_transaction_id: entity_transaction.id,
        cash_transaction_id: nil,
        bound_type: "standalone",
        exchange_type: Exchange.exchange_types.fetch(:monetary),
        number: 1,
        date: now,
        month: now.month,
        year: now.year,
        price: 25,
        starting_price: 25,
        exchanges_count: 1,
        created_at: now,
        updated_at: now
      )
    end

    version = AuditVersion.find_by!(item: exchange, event: :create)
    expect(version).to have_attributes(owner_id: user.id, context_id: context.id, mutation_source: "admin_repair")
    expect(version.object_changes).to include("price" => [ nil, 25 ])
    expect(version.object_changes).not_to include("cash_transaction_id", "exchanges_count", "created_at", "updated_at")
    expect(exchange.cash_transaction_id).to be_nil
  end

  it "clears an association cache after capturing bulk destruction" do
    installments = transaction.cash_installments
    deleted_installment = installments.first

    Audit::Operation.run(actor: user, context:, source: :admin_repair) do
      described_class.delete_all!(installments)
    end
    replacement = installments.create!(
      number: 1,
      price: 500,
      date: Time.zone.today,
      month: Time.zone.today.month,
      year: Time.zone.today.year,
      paid: false
    )

    expect(installments.first).to eq(replacement)
    expect(installments).not_to include(deleted_installment)
  end

  it "compares and versions direct updates from database state when the caller is stale" do
    transaction
    original_description = transaction.description
    transaction.description = "Corrected in memory"

    Audit::Operation.run(actor: user, context:, source: :admin_repair) do
      described_class.update_columns!(transaction, description: "Corrected in memory")
    end

    version = AuditVersion.find_by!(item: transaction, event: :update)
    expect(transaction.reload.description).to eq("Corrected in memory")
    expect(version.object_changes).to eq("description" => [ original_description, "Corrected in memory" ])
    expect(version.object.fetch("description")).to eq(original_description)
  end
end
