# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::NamingConventions::Apply do
  let(:admin) { create(:user, :random, admin: true) }
  let(:scope) { HealthCheck::Scope.new(user: admin, context: admin.main_context) }

  it "rolls back every naming change when one mutation fails" do
    transactions = 2.times.map { create_naming_candidate }
    preview = HealthCheck::NamingConventions::Preview.new(scope:)
    calls = 0

    allow(Audit::BulkMutation).to receive(:update_columns!).and_wrap_original do |method, *arguments|
      calls += 1
      raise ActiveRecord::RecordInvalid, arguments.first if calls == 2

      method.call(*arguments)
    end

    expect do
      result = described_class.new(
        scope:,
        request_id: "atomic-naming-repair",
        token: preview.apply_token,
        confirmed: true
      ).call

      expect(result).to have_attributes(status: "rejected", reason_code: "validation_failed")
    end.to change(AuditOperation, :count).by(0).and change(AuditVersion, :count).by(0)

    expect(transactions.map { |transaction| transaction.reload.description }).to all(eq("OUTDATED NAMING"))
  end

  it "binds the signed preview to its administrator and context" do
    create_naming_candidate
    preview = HealthCheck::NamingConventions::Preview.new(scope:)
    other_admin = create(:user, :random, admin: true)
    other_scope = HealthCheck::Scope.new(user: other_admin, context: other_admin.main_context)

    result = described_class.new(
      scope: other_scope,
      request_id: "foreign-naming-repair",
      token: preview.apply_token,
      confirmed: true
    ).call

    expect(result).to have_attributes(status: "rejected", reason_code: "token_actor_mismatch")
  end

  private

  def create_naming_candidate
    investment = create(
      :investment,
      :random,
      user: admin,
      context: admin.main_context,
      user_bank_account: create(:user_bank_account, :random, user: admin),
      investment_type: create(:investment_type, :random)
    )
    investment.cash_transaction.tap { |transaction| transaction.update_columns(description: "OUTDATED NAMING") }
  end
end
