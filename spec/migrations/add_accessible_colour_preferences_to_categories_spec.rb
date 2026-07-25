# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260725120000_add_accessible_colour_preferences_to_categories")

RSpec.describe AddAccessibleColourPreferencesToCategories do
  subject(:migration) { described_class.new }

  it "captures every current legacy palette value at its exact rendered hex" do
    expected_palette = COLOURS.to_h.transform_values { |value| value.fetch(:hex).downcase }

    expect(described_class::LEGACY_PALETTE).to eq(expected_palette)
  end

  it "normalizes legacy names, short hex, uppercase hex, and surrounding whitespace" do
    expect(normalize("white")).to eq("#f1f5f9")
    expect(normalize(" OLDMONEY ")).to eq("#b9c58f")
    expect(normalize("#AbC")).to eq("#aabbcc")
    expect(normalize(" A1B2C3 ")).to eq("#a1b2c3")
  end

  it "refuses to invent a replacement for an unknown persisted value" do
    expect { normalize("transparent", category_id: 91) }
      .to raise_error(ActiveRecord::MigrationError, /Cannot normalize category #91 colour "transparent"/)
  end

  def normalize(value, category_id: 12)
    migration.send(:normalize_colour, value, category_id:)
  end
end
