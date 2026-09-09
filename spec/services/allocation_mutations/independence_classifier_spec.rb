# frozen_string_literal: true

require "rails_helper"

RSpec.describe AllocationMutations::IndependenceClassifier do
  let(:plan_class) do
    Data.define(:status, :reason_code, :graph_keys) do
      def eligible? = status == :eligible
      def conflict? = status == :conflict
      def outcome = Data.define(:reason_code).new(reason_code:)
    end
  end

  it "retains reason-based structural protection when no graph resolver is supplied" do
    plans = [
      plan_class.new(status: :eligible, reason_code: :ready, graph_keys: [ "CashTransaction:1" ]),
      plan_class.new(status: :conflict, reason_code: :subscription_owned_entity, graph_keys: [ "Subscription:2" ])
    ]

    expect(described_class.new(plans:).eligible_only_available?).to be(false)
  end

  it "accepts structurally independent eligible and conflict graphs" do
    plans = [
      plan_class.new(status: :eligible, reason_code: :ready, graph_keys: [ "CashTransaction:1" ]),
      plan_class.new(status: :conflict, reason_code: :subscription_owned_entity, graph_keys: [ "Subscription:2" ])
    ]

    result = described_class.new(plans:, dependency_keys: lambda(&:graph_keys))

    expect(result.eligible_only_available?).to be(true)
  end

  it "rejects eligible-only when an eligible and conflict plan share a graph key" do
    plans = [
      plan_class.new(status: :eligible, reason_code: :ready, graph_keys: [ "CashTransaction:1", "CashTransaction:2" ]),
      plan_class.new(status: :conflict, reason_code: :monetary_entity, graph_keys: [ "CashTransaction:2" ])
    ]

    result = described_class.new(plans:, dependency_keys: lambda(&:graph_keys))

    expect(result.eligible_only_available?).to be(false)
  end
end
