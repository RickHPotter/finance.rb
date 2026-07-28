# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryColours::Ordering do
  let(:ordinary_first) { Category.new(id: 11, category_name: "Ordinary first", built_in: false) }
  let(:built_in_first) { Category.new(id: 12, category_name: "SUBSCRIPTION", built_in: true) }
  let(:ordinary_second) { Category.new(id: 13, category_name: "Ordinary second", built_in: false) }
  let(:built_in_second) { Category.new(id: 14, category_name: "INVESTMENT", built_in: true) }
  let(:failed_return) { Category.new(id: 15, category_name: "FAILED LEND/BORROW RETURN", built_in: true) }

  it "moves built-in categories first while preserving allocation order within each group" do
    ordered = described_class.call([ ordinary_first, built_in_first, ordinary_second, built_in_second ])

    expect(ordered).to eq([ built_in_first, built_in_second, ordinary_first, ordinary_second ])
  end

  it "keeps the established failed-return category ahead of other built-ins" do
    ordered = described_class.call([ built_in_first, ordinary_first, failed_return, built_in_second ])

    expect(ordered).to eq([ failed_return, built_in_first, built_in_second, ordinary_first ])
  end

  it "removes nil and duplicate categories without changing precedence" do
    ordered = described_class.call([ ordinary_first, nil, built_in_first, ordinary_first, built_in_first ])

    expect(ordered).to eq([ built_in_first, ordinary_first ])
  end

  it "orders allocation records by id before applying built-in precedence" do
    allocation = Data.define(:id, :category)
    allocations = [
      allocation.new(30, ordinary_second),
      allocation.new(10, ordinary_first),
      allocation.new(20, built_in_first)
    ]

    expect(described_class.from_allocations(allocations)).to eq([ built_in_first, ordinary_first, ordinary_second ])
  end
end
