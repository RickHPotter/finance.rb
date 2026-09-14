# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::References do
  describe ".merge" do
    let(:user) { create(:user, :random) }
    let(:user_card) { create(:user_card, :random, user:) }

    it "exposes the stable merge modes" do
      expect(described_class::MERGE_MODES).to contain_exactly(
        described_class::COMBINE_INTO_TARGET,
        described_class::REALLOCATE_INSTALLMENTS
      )
    end

    it "returns one structured rejection contract for invalid mode, date, and graph inputs" do
      invalid_mode = described_class.merge_result(user_card, "invalid", "invalid", merge_mode: "unknown", context: user.main_context)
      invalid_date = described_class.merge_result(
        user_card,
        "invalid",
        "2026-09-01",
        merge_mode: described_class::COMBINE_INTO_TARGET,
        context: user.main_context
      )
      missing_graph = described_class.merge_result(
        user_card,
        "2026-08-01",
        "2026-09-01",
        merge_mode: described_class::COMBINE_INTO_TARGET,
        context: user.main_context
      )

      expect(invalid_mode).to have_attributes(status: "rejected", reason_code: "invalid_mode", plan: nil, operation: nil)
      expect(invalid_date).to have_attributes(status: "rejected", reason_code: "invalid_date", plan: nil, operation: nil)
      expect(missing_graph).to have_attributes(status: "rejected", reason_code: "combine_missing_root", plan: nil, operation: nil)
    end

    it "rejects an unknown mode before parsing dates or writing audit history" do
      user_card

      expect do
        result = described_class.merge(user_card, "invalid", "invalid", merge_mode: "unknown", context: user.main_context)

        expect(result).to be(false)
      end.not_to change(AuditOperation, :count)
    end

    it "rejects malformed dates for either recognized mode without writing audit history" do
      user_card

      described_class::MERGE_MODES.each do |merge_mode|
        expect do
          result = described_class.merge(user_card, "invalid", "2026-09-01", merge_mode:, context: user.main_context)

          expect(result).to be(false)
        end.not_to change(AuditOperation, :count)
      end
    end

    it "keeps reallocation fail-closed when its required invoice graph is absent" do
      user_card

      expect do
        result = described_class.merge(
          user_card,
          "2026-08-01",
          "2026-09-01",
          merge_mode: described_class::REALLOCATE_INSTALLMENTS,
          context: user.main_context
        )

        expect(result).to be(false)
      end.not_to change(AuditOperation, :count)
    end
  end
end
