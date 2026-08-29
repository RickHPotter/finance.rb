# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranslateHelper do
  subject(:helper) { Object.new.extend(described_class) }

  describe "#localized_cent_based_currency" do
    it "uses English separators for an English display" do
      I18n.with_locale(:en) do
        expect(helper.localized_cent_based_currency(100_000, "R$")).to eq("R$ 1,000.00")
      end
    end

    it "uses Brazilian Portuguese separators for a Brazilian display" do
      I18n.with_locale(:"pt-BR") do
        expect(helper.localized_cent_based_currency(100_000, "R$")).to eq("R$ 1.000,00")
      end
    end

    it "places a negative sign after the currency unit" do
      I18n.with_locale(:en) do
        expect(helper.localized_cent_based_currency(-7_500, "R$")).to eq("R$ -75.00")
      end

      I18n.with_locale(:"pt-BR") do
        expect(helper.localized_cent_based_currency(-7_500, "R$")).to eq("R$ -75,00")
      end
    end
  end
end
