# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Budgets do
  it "does not mix budgets into an exact cash-installment result" do
    user = create(:user, :random)
    context = user.main_context
    create(:budget, user:, context:, month: 4, year: 2026)

    result = described_class.find_by_ref_month_year(
      context,
      4,
      2026,
      { cash_installment_ids: [ 123 ], associations: {} }.with_indifferent_access
    )

    expect(result).to be_empty
  end
end
