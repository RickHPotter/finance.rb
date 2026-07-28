# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryColours::Presentation, type: :service do
  describe ".for" do
    it "builds an immutable presentation from a category's validated manual pair" do
      category = build_stubbed(:category, category_name: "Snow", colour: "#ffffff", text_colour_mode: "manual", text_colour: "#767676")

      presentation = described_class.for(category)

      expect(presentation.background).to eq("#ffffff")
      expect(presentation.foreground).to eq("#767676")
      expect(presentation.border_colour).to eq("#767676")
      expect(presentation.contrast_ratio).to be_within(0.001).of(4.542)
      expect(presentation.ratio_label).to eq("4.54:1")
      expect(presentation.chart_background).to eq("#ffffff")
      expect(presentation.chart_foreground).to eq("#767676")
      expect(presentation.chart_payload).to eq(background: "#ffffff", foreground: "#767676")
      expect(presentation).not_to be_fallback
      expect(presentation).to be_frozen
    end

    it "provides a safe neutral fallback for missing or invalid categories" do
      invalid_category = build_stubbed(:category, colour: "#ffffff", text_colour_mode: "manual", text_colour: "#777777")

      expect(described_class.for(nil)).to equal(described_class.neutral)
      expect(described_class.for(invalid_category)).to equal(described_class.neutral)
      expect(described_class.neutral).to be_fallback
      expect(described_class.neutral.contrast_ratio).to be >= CategoryColours::Contrast::MINIMUM_RATIO
    end

    it "refuses to construct an inaccessible pair directly" do
      expect { described_class.new(background: "#ffffff", foreground: "#777777") }
        .to raise_error(described_class::InaccessiblePair, /must meet 4.5:1/)
    end
  end

  describe ".bundle" do
    it "uses the category presentation for a single-category bundle" do
      category = build_stubbed(:category, category_name: "Food", colour: "#ffffff")
      bundle = described_class.bundle(category)

      expect(bundle.segments.one?).to be(true)
      expect(bundle.combined).to eq(bundle.segments.first.presentation)
      expect(bundle.label).to eq("Food")
      expect(bundle).not_to be_empty
      expect(bundle).not_to be_multiple
    end

    it "uses independently resolved segments and a neutral combined surface for multiple categories" do
      user = build_stubbed(:user)
      light = build_stubbed(:category, id: 11, user:, category_name: "Light", colour: "#ffffff")
      dark = build_stubbed(:category, id: 12, user:, category_name: "Dark", colour: "#000000")
      bundle = described_class.bundle([ light, dark, light ])

      expect(bundle.segments.map(&:label)).to eq(%w[Light Dark])
      expect(bundle.segments.map { |segment| segment.presentation.foreground }).to eq(%w[#000000 #ffffff])
      expect(bundle.combined).to equal(described_class.neutral)
      expect(bundle.chart_payload).to eq(
        background: described_class.neutral.background,
        foreground: described_class.neutral.foreground,
        segments: [
          { id: light.id, label: "Light", background: "#ffffff", foreground: "#000000" },
          { id: dark.id, label: "Dark", background: "#000000", foreground: "#ffffff" }
        ]
      )
      expect(bundle.label).to eq("Light + Dark")
      expect(bundle).to be_multiple
      expect(bundle).to be_frozen
      expect(bundle.segments).to be_frozen
      expect(bundle.segments).to all(be_frozen)
      expect(bundle.segments.map(&:label)).to all(be_frozen)
    end

    it "returns a neutral empty bundle without inventing a category" do
      bundle = described_class.bundle([])

      expect(bundle).to be_empty
      expect(bundle.label).to eq("")
      expect(bundle.combined).to equal(described_class.neutral)
    end
  end

  describe "interaction styles" do
    subject(:presentation) { described_class.new(background: "#ffffff", foreground: "#000000") }

    it "keeps the accessible pair while exposing two-layer focus variables" do
      expect(presentation.inline_style).to include(
        "background-color: #ffffff",
        "color: #000000",
        "border-color: #000000",
        "--category-focus-inner: #ffffff",
        "--category-focus-outer: #000000"
      )
    end

    it "uses decoration rather than opacity or brightness for selected and disabled states" do
      expect(presentation.selected_style).to include("background-color: #ffffff", "color: #000000", "box-shadow:")
      expect(presentation.disabled_style).to include("background-color: #ffffff", "color: #000000", "border-style: dashed")
      expect(presentation.selected_style).not_to match(/opacity|brightness|filter/)
      expect(presentation.disabled_style).not_to match(/opacity|brightness|filter/)
    end
  end
end
