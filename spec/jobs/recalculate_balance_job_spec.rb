# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecalculateBalanceJob, type: :job do
  describe "#perform" do
    it "recalculates every user context when no explicit context is given" do
      user = create(:user, :random)
      derived_context = create(:context, user:, name: "Derived", source_context: user.main_context)
      main_service = instance_double(Logic::RecalculateBalancesService, call: true)
      derived_service = instance_double(Logic::RecalculateBalancesService, call: true)

      expect(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: user.main_context).ordered.and_return(main_service)
      expect(main_service).to receive(:call).ordered
      expect(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: derived_context).ordered.and_return(derived_service)
      expect(derived_service).to receive(:call).ordered

      described_class.perform_now(user:)
    end

    it "recalculates only the provided context when explicit" do
      user = create(:user, :random)
      derived_context = create(:context, user:, name: "Derived", source_context: user.main_context)
      service = instance_double(Logic::RecalculateBalancesService, call: true)

      expect(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: derived_context).and_return(service)
      expect(service).to receive(:call)

      described_class.perform_now(user:, context: derived_context)
    end
  end
end
