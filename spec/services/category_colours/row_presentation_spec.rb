# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryColours::RowPresentation do
  let(:dark_category) { Category.new(id: 11, category_name: "Dark", colour: "#4b5563") }
  let(:light_category) { Category.new(id: 148, category_name: "Light", colour: "#f1f5f9") }

  it "uses the normal application surface and resolved badges in badges-only mode" do
    presentation = described_class.new(categories: [ dark_category ], mode: "badges_only")

    expect(presentation.mode).to eq("badges_only")
    expect(presentation).to be_badges_only
    expect(presentation.row_style).to be_nil
    expect(presentation.row_classes).to include("bg-white", "dark:bg-slate-900")
    expect(presentation.badge_style(dark_category)).to include("background-color: #4b5563", "color: #ffffff")
    expect(presentation.metadata).to eq(category_display_mode: "badges_only", category_multiple: "false", category_primary_id: 11)
  end

  it "uses one category's complete pair for a row-coloured surface" do
    presentation = described_class.new(categories: [ light_category ], mode: "row_coloured")

    expect(presentation).to be_row_coloured
    expect(presentation.row_style).to include("background-color: #f1f5f9", "color: #000000")
    expect(presentation.row_style).to include(
      "--category-row-foreground: #000000",
      "--category-row-info-foreground: #000000"
    )
    expect(presentation.row_classes).to be_nil
    expect(presentation.metadata).to eq(category_display_mode: "row_coloured", category_multiple: "false", category_primary_id: 148)
  end

  it "prioritizes built-ins for a multi-category row without hiding badge pairs" do
    built_in_category = Category.new(id: 148, category_name: "SUBSCRIPTION", built_in: true, colour: "#f1f5f9")
    presentation = described_class.new(categories: [ dark_category, built_in_category ], mode: "row_coloured")

    expect(presentation.primary_category_key).to eq(148)
    expect(presentation.row_style).to include("background-color: #f1f5f9", "color: #000000")
    expect(presentation.row_style).to include(
      "--category-row-foreground: #000000",
      "--category-row-info-foreground: #000000"
    )
    expect(presentation.metadata).to include(category_multiple: "true")
    expect(presentation.badge_style(dark_category)).to include("background-color: #4b5563", "color: #ffffff")
    expect(presentation.badge_style(built_in_category)).to include("background-color: #f1f5f9", "color: #000000")
  end

  it "uses the application surface when row-coloured mode has no category" do
    presentation = described_class.new(categories: [], mode: "row_coloured")

    expect(presentation).to be_badges_only
    expect(presentation.row_style).to be_nil
    expect(presentation.metadata).to eq(category_display_mode: "row_coloured", category_multiple: "false")
  end
end
