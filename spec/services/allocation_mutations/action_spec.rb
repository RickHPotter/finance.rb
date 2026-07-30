# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::Action do
  it "normalizes supported category and entity operations" do
    add = described_class.new(allocation_type: "category", operation: "add", destination_id: "12")
    remove = described_class.new(allocation_type: :entity, operation: :remove, source_id: 13)
    switch = described_class.new(allocation_type: :entity, operation: :switch, source_id: 13, destination_id: 14)

    expect(add).to have_attributes(allocation_type: :category, operation: :add, source_id: nil, destination_id: 12)
    expect(remove).to have_attributes(allocation_type: :entity, operation: :remove, source_id: 13, destination_id: nil)
    expect(switch).to have_attributes(allocation_type: :entity, operation: :switch, source_id: 13, destination_id: 14)
    expect([ add.add?, remove.remove?, switch.switch? ]).to all(be(true))
  end

  it "rejects unsupported types, operations, and identifier shapes" do
    expect { described_class.new(allocation_type: :budget, operation: :add, destination_id: 1) }.to raise_error(ArgumentError, /allocation type/)
    expect { described_class.new(allocation_type: :category, operation: :merge, destination_id: 1) }.to raise_error(ArgumentError, /allocation operation/)
    expect { described_class.new(allocation_type: :category, operation: :add, source_id: 1, destination_id: 2) }.to raise_error(ArgumentError, /destination/)
    expect { described_class.new(allocation_type: :entity, operation: :remove) }.to raise_error(ArgumentError, /source/)
    expect { described_class.new(allocation_type: :entity, operation: :switch, source_id: 1) }.to raise_error(ArgumentError, /source and destination/)
    expect { described_class.new(allocation_type: :entity, operation: :add, destination_id: 0) }.to raise_error(ArgumentError, /positive integers/)
  end
end
