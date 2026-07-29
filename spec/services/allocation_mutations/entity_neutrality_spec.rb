# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::EntityNeutrality do
  let(:allocation) do
    EntityTransaction.new(
      is_payer: false,
      price: 0,
      price_to_be_returned: 0,
      exchanges: []
    )
  end

  it "accepts only a zero, non-payer, exchange-free allocation" do
    expect(described_class.neutral?(allocation)).to be(true)
    expect(described_class.reasons(allocation)).to eq([])
  end

  it "reports every reason that makes an allocation non-neutral" do
    allocation.assign_attributes(is_payer: true, price: 10, price_to_be_returned: 20)
    allocation.exchanges.build(price: 10, number: 1, month: 1, year: 2026, date: Date.new(2026, 1, 1))

    expect(described_class.neutral?(allocation)).to be(false)
    expect(described_class.reasons(allocation)).to contain_exactly(:payer, :price, :return, :exchanges)
  end
end
