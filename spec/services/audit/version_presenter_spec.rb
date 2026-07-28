# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::VersionPresenter do
  let(:operation) { AuditOperation.create!(source: :web, result: :committed) }
  let(:version) do
    AuditVersion.create!(
      operation:,
      owner_id: 17,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: 31,
      event: :update,
      mutation_source: :web,
      object_changes: {
        "paid" => [ false, true ],
        "price" => [ 1_000, 2_500 ],
        "description" => %w[Before After]
      },
      metadata: { "user_bank_account_id" => 9 }
    )
  end

  it "renders translated labels and typed before/after values" do
    changes = described_class.new(version).changes.index_by(&:attribute)

    expect(changes.fetch("description")).to have_attributes(label: CashTransaction.human_attribute_name(:description), before: "Before", after: "After")
    expect(changes.fetch("paid")).to have_attributes(before: I18n.t("audit.values.false"), after: I18n.t("audit.values.true"))
    currency_unit = I18n.t("number.currency.format.unit")
    expect(changes.fetch("price")).to have_attributes(before: "#{currency_unit} 10.00", after: "#{currency_unit} 25.00")

    I18n.with_locale(:"pt-BR") do
      localized_changes = described_class.new(version).changes.index_by(&:attribute)
      expect(localized_changes.fetch("price")).to have_attributes(before: "R$ 10,00", after: "R$ 25,00")
    end
  end
end
