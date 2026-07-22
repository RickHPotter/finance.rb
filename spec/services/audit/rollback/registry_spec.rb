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
end
