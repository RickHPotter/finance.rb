# frozen_string_literal: true

require "rails_helper"

RSpec.describe Components::CategoryBadge, type: :component do
  let(:category) { build_stubbed(:category, id: 42, category_name: "Readable", colour: "#ffffff") }

  it "renders the resolved pair and accessible metadata" do
    document = render_component(category:, id: "category_badge_42")
    badge = document.at_css("#category_badge_42")

    expect(badge.name).to eq("span")
    expect(badge.text).to eq("Readable")
    expect(badge["style"]).to include("background-color: #ffffff", "color: #000000")
    expect(badge["data-category-colour"]).to eq("true")
    expect(badge["data-category-id"]).to eq("42")
    expect(badge["data-contrast-ratio"]).to eq("21.00:1")
    expect(badge["aria-label"]).to eq("Readable")
  end

  it "renders a keyboard-focusable link without changing its colour pair on hover" do
    document = render_component(category:, href: "/categories/42")
    badge = document.at_css("a")

    expect(badge["href"]).to eq("/categories/42")
    expect(badge["class"]).to include("hover:shadow-md", "focus-visible:ring-2")
    expect(badge["class"]).not_to match(/hover:(opacity|brightness)|hover:text-|hover:bg-/)
  end

  it "renders selected state through decoration while preserving the pair" do
    document = render_component(category:, href: "/categories/42", selected: true)
    badge = document.at_css("a")

    expect(badge["aria-current"]).to eq("true")
    expect(badge["data-selected"]).to eq("true")
    expect(badge["style"]).to include("background-color: #ffffff", "color: #000000", "box-shadow:")
  end

  it "renders disabled state as a non-link without reducing text contrast" do
    document = render_component(category:, href: "/categories/42", disabled: true)
    badge = document.at_css("span")

    expect(badge["href"]).to be_nil
    expect(badge["aria-disabled"]).to eq("true")
    expect(badge["class"]).to include("cursor-not-allowed", "border-dashed")
    expect(badge["style"]).to include("background-color: #ffffff", "color: #000000")
    expect(badge["style"]).not_to match(/opacity|brightness|filter/)
  end

  it "renders a compact swatch with an accessible category name" do
    document = render_component(category:, variant: :swatch)
    swatch = document.at_css("span[data-category-colour]")

    expect(swatch["class"]).to include("size-5", "rounded-full")
    expect(swatch.at_css(".sr-only").text).to eq("Readable")
    expect(swatch["aria-label"]).to eq("Readable")
  end

  it "rejects unknown variants" do
    expect { described_class.new(category:, variant: :unknown) }.to raise_error(ArgumentError, "invalid category badge variant")
  end

  context "when category is a subcategory" do
    let(:user) { build_stubbed(:user) }
    let(:parent) { build_stubbed(:category, id: 10, user:, category_name: "HSH", colour: "#000000", text_colour: "#ffffff", text_colour_mode: "manual") }
    let(:child) do
      build_stubbed(:category, id: 42, user:, category_name: "LABOUR", colour: "#ffffff", text_colour: "#000000", text_colour_mode: "manual", parent_category: parent)
    end

    it "renders a compound badge wrapping parent name and child badge" do
      document = render_component(category: child, id: "category_badge_42")
      badge = document.at_css("#category_badge_42")

      expect(badge.name).to eq("span")
      expect(badge.text).to include("HSH")
      expect(badge.text).to include("LABOUR")
      expect(badge["style"]).to include("background-color: #000000")
      expect(badge["aria-label"]).to eq("HSH - LABOUR")

      child_badge = badge.at_css("[data-category-child-badge='true']")
      expect(child_badge).to be_present
      expect(child_badge.text).to eq("LABOUR")
      expect(child_badge["style"]).to include("background-color: #ffffff")
    end

    it "renders a link compound badge when href is provided" do
      document = render_component(category: child, href: "/categories/42")
      badge = document.at_css("a")

      expect(badge["href"]).to eq("/categories/42")
      expect(badge.at_css("[data-category-child-badge='true']")).to be_present
    end

    it "renders single badge when compound: false is passed" do
      document = render_component(category: child, compound: false)
      badge = document.at_css("span")

      expect(badge.text).to eq("LABOUR")
      expect(badge.at_css("[data-category-child-badge='true']")).to be_nil
    end

    it "renders swatch with accessible compound name" do
      document = render_component(category: child, variant: :swatch)
      swatch = document.at_css("span[data-category-colour]")

      expect(swatch["class"]).to include("size-5", "rounded-full")
      expect(swatch["aria-label"]).to eq("HSH - LABOUR")
      expect(swatch.at_css(".sr-only").text).to eq("HSH - LABOUR")
    end
  end

  def render_component(**attributes)
    Nokogiri::HTML.fragment(described_class.new(**attributes).call)
  end
end
