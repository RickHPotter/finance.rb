# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::CashInstallments::Index do
  describe "#entity_exchanges_info" do
    it "falls back to the exchange amounts when the return amount is zero" do
      exchanges = [ instance_double(Exchange, price: 3_000), instance_double(Exchange, price: 4_000) ]
      entity_transaction = instance_double(
        EntityTransaction,
        exchanges_count: 2,
        price_to_be_returned: 0,
        exchanges:
      )

      info = described_class.allocate.send(:entity_exchanges_info, entity_transaction)

      expect(info).to eq("[R$ 70.00] (2)")
    end
  end
end
