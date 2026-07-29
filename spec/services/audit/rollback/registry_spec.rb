# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Registry do
  let(:expected_types) do
    %w[
      Budget
      BudgetCategory
      BudgetEntity
      CardInstallment
      CardTransaction
      CashInstallment
      CashTransaction
      CategoryTransaction
      EntityTransaction
      Exchange
      Investment
      PiggyBank
      Reference
      Subscription
      UserBankAccount
      UserCard
    ]
  end

  it "registers transaction, installment, and allocation families explicitly" do
    expect(described_class.supported_types).to contain_exactly(*expected_types)
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
      "Subscription" => Audit::Rollback::Adapters::Subscription,
      "Investment" => Audit::Rollback::Adapters::Investment,
      "Exchange" => Audit::Rollback::Adapters::Exchange,
      "PiggyBank" => Audit::Rollback::Adapters::PiggyBank
    )
  end

  it "registers every concrete financially audited model" do
    Rails.application.eager_load!
    audited_types = ApplicationRecord.descendants.filter_map do |model|
      next unless model.name.present? && model.respond_to?(:paper_trail_options) && model.paper_trail_options.present?
      next if model == Installment || model.abstract_class?

      model.name
    end

    expect(audited_types).to contain_exactly(*expected_types)
    expect(described_class.supported_types).to contain_exactly(*audited_types)
  end

  it "provides bilingual UI copy for every declared recalculation and graph-specific conflict" do
    recalculations = described_class::ADAPTERS.values.uniq.flat_map do |adapter|
      adapter.const_defined?(:RECALCULATIONS, false) ? adapter.const_get(:RECALCULATIONS) : []
    end.uniq
    keys = recalculations.map { |key| "audit.rollback.recalculations.#{key}" }
    keys += %w[
      audit.rollback.issues.missing_investment_projection
      audit.rollback.issues.missing_piggy_bank_return
    ]

    %i[en pt-BR].each do |locale|
      expect(keys).to all(satisfy { |key| I18n.exists?(key, locale) })
    end
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
