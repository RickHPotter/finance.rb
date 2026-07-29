# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Registry do
  it "registers transaction, installment, and allocation families explicitly" do
    expect(described_class.supported_types).to contain_exactly(
      "CashTransaction",
      "CardTransaction",
      "CashInstallment",
      "CardInstallment",
      "CategoryTransaction",
      "EntityTransaction",
      "Budget",
      "BudgetCategory",
      "BudgetEntity",
      "Reference",
      "UserCard",
      "UserBankAccount",
      "Subscription"
    )
    expect(described_class::ADAPTERS).to eq(
      "CashTransaction" => Audit::Rollback::Adapters::CashTransaction,
      "CardTransaction" => Audit::Rollback::Adapters::CardTransaction,
      "CashInstallment" => Audit::Rollback::Adapters::Installment,
      "CardInstallment" => Audit::Rollback::Adapters::Installment,
      "CategoryTransaction" => Audit::Rollback::Adapters::CategoryTransaction,
      "EntityTransaction" => Audit::Rollback::Adapters::EntityTransaction,
      "Budget" => Audit::Rollback::Adapters::Budget,
      "BudgetCategory" => Audit::Rollback::Adapters::BudgetCategory,
      "BudgetEntity" => Audit::Rollback::Adapters::BudgetEntity,
      "Reference" => Audit::Rollback::Adapters::Reference,
      "UserCard" => Audit::Rollback::Adapters::UserCard,
      "UserBankAccount" => Audit::Rollback::Adapters::UserBankAccount,
      "Subscription" => Audit::Rollback::Adapters::Subscription
    )
  end

  it "registers Subscription audit operations for rollback" do
    user = create(:user, :random)
    admin = create(:user, :random, admin: true)
    operation = nil

    Audit::Operation.run(actor: user, context: user.main_context, source: :web) do
      create(:subscription, user:, context: user.main_context)
      operation = Audit::Operation.ensure_persisted!
    end

    expect(operation.audit_versions.where(item_type: "Subscription", event: :create)).to exist
    expect(Audit::Rollback::Preview.new(operation:, actor: admin)).to have_attributes(state: "previewable")
    expect(described_class.supported_types).to include("Subscription")
  end
end
