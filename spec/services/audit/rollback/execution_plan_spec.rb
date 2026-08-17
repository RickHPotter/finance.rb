# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::ExecutionPlan do
  let(:row_class) { Data.define(:key, :action, :dependencies) }

  def row(key, action: "update", dependencies: [])
    row_class.new(key:, action:, dependencies:)
  end

  def dependency(key, relationship:)
    record_type, item_id = key.split(":")
    Audit::Rollback::Dependency.new(record_type:, item_id:, relationship:, included: true)
  end

  it "orders recreation and updates from parents to children deterministically" do
    child = row("Child:2", action: "recreate", dependencies: [ dependency("Parent:1", relationship: :parent) ])
    unrelated = row("Account:3")
    parent = row("Parent:1", action: "recreate")

    plan = described_class.new(rows: [ child, parent, unrelated ])

    expect(plan.ordered_rows.map(&:key)).to eq(%w[Account:3 Parent:1 Child:2])
  end

  it "orders destruction from children to parents" do
    parent = row("Parent:1", action: "destroy", dependencies: [ dependency("Child:2", relationship: :dependent) ])
    child = row("Child:2", action: "destroy", dependencies: [ dependency("Parent:1", relationship: :parent) ])

    plan = described_class.new(rows: [ parent, child ])

    expect(plan.ordered_rows.map(&:key)).to eq(%w[Child:2 Parent:1])
  end

  it "moves an updated child away before destroying its current parent" do
    parent = row("Parent:1", action: "destroy")
    child = row("Child:2", action: "update", dependencies: [ dependency("Parent:1", relationship: :parent) ])

    plan = described_class.new(rows: [ parent, child ])

    expect(plan.ordered_rows.map(&:key)).to eq(%w[Child:2 Parent:1])
  end

  it "rejects dependency cycles" do
    first = row("First:1", dependencies: [ dependency("Second:2", relationship: :parent) ])
    second = row("Second:2", dependencies: [ dependency("First:1", relationship: :parent) ])

    expect { described_class.new(rows: [ first, second ]).ordered_rows }
      .to raise_error(described_class::InvalidGraphError) { |error| expect(error).to have_attributes(code: "cyclic_dependencies") }
  end

  it "rejects duplicate row keys" do
    rows = [ row("Duplicate:1"), row("Duplicate:1") ]

    expect { described_class.new(rows:).ordered_rows }
      .to raise_error(described_class::InvalidGraphError) { |error| expect(error).to have_attributes(code: "duplicate_keys") }
  end

  it "rejects an included dependency without a corresponding row" do
    orphan = row("Child:2", dependencies: [ dependency("Parent:1", relationship: :parent) ])

    expect { described_class.new(rows: [ orphan ]).ordered_rows }
      .to raise_error(described_class::InvalidGraphError) { |error| expect(error).to have_attributes(code: "missing_included_dependency") }
  end

  it "rejects dependency relationships outside the adapter contract" do
    parent = row("Parent:1")
    child = row("Child:2", dependencies: [ dependency("Parent:1", relationship: :sidecar) ])

    expect { described_class.new(rows: [ parent, child ]).ordered_rows }
      .to raise_error(described_class::InvalidGraphError) { |error| expect(error).to have_attributes(code: "unknown_relationship") }
  end
end
