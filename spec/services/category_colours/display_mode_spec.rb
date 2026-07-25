# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryColours::DisplayMode do
  describe ".for" do
    it "reads the future user preference when the model exposes it" do
      user = Data.define(:category_colour_display_mode).new("row_coloured")

      expect(described_class.for(user)).to eq("row_coloured")
    end

    it "uses the default before the preference column exists" do
      expect(described_class.for(Object.new)).to eq("row_coloured")
    end
  end

  describe ".resolve" do
    it "accepts only canonical persisted strings" do
      expect(described_class.resolve("row_coloured")).to eq("row_coloured")
      expect(described_class.resolve("badges_only")).to eq("badges_only")
    end

    it "falls back safely for blank, symbol, and unknown values" do
      expect(described_class.resolve(nil)).to eq("row_coloured")
      expect(described_class.resolve("")).to eq("row_coloured")
      expect(described_class.resolve(:row_coloured)).to eq("row_coloured")
      expect(described_class.resolve("gradient")).to eq("row_coloured")
    end
  end
end
