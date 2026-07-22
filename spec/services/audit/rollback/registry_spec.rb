# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Registry do
  it "registers the initial ordinary transaction and installment families explicitly" do
    expect(described_class.supported_types).to contain_exactly(
      "CashTransaction",
      "CardTransaction",
      "CashInstallment",
      "CardInstallment"
    )
    expect(described_class::ADAPTERS).to eq(
      "CashTransaction" => Audit::Rollback::Adapters::CashTransaction,
      "CardTransaction" => Audit::Rollback::Adapters::CardTransaction,
      "CashInstallment" => Audit::Rollback::Adapters::Installment,
      "CardInstallment" => Audit::Rollback::Adapters::Installment
    )
  end

  it "keeps audit capture enabled for a family without a rollback adapter" do
    user = create(:user, :random)
    admin = create(:user, :random, admin: true)
    operation = nil

    Audit::Operation.run(actor: user, context: user.main_context, source: :web) do
      create(:budget, user:, context: user.main_context)
      operation = Audit::Operation.ensure_persisted!
    end

    expect(operation.audit_versions.where(item_type: "Budget", event: :create)).to exist
    expect(Audit::Rollback::Preview.new(operation:, actor: admin)).to have_attributes(state: "read_only")
    expect(described_class.supported_types).not_to include("Budget")
  end
end
