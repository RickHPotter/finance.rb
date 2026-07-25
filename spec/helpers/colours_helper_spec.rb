# frozen_string_literal: true

require "rails_helper"

RSpec.describe ColoursHelper, type: :helper do
  subject(:helper_object) { Class.new { include ColoursHelper }.new }

  it "delegates automatic foreground resolution to the contrast contract" do
    expect(helper_object.auto_text_color("#ffffff")).to eq("color: #000000;")
    expect(helper_object.auto_text_color("#0000ff")).to eq("color: #ffffff;")
    expect(helper_object.auto_text_color("invalid")).to eq("color: #000000;")
  end

  it "honours a validated manual foreground for a single category" do
    category = build_stubbed(:category, colour: "#ffffff", text_colour_mode: "manual", text_colour: "#767676")

    expect(helper_object.solid_or_gradient_style(category)).to include("background-color: #ffffff", "color: #767676")
  end

  it "uses the accessible neutral surface instead of text over a multi-category gradient" do
    user = build_stubbed(:user)
    categories = [
      build_stubbed(:category, id: 11, user:, colour: "#ffffff"),
      build_stubbed(:category, id: 12, user:, colour: "#000000")
    ]

    style = helper_object.solid_or_gradient_style(categories)

    expect(style).to include("background-color: #e2e8f0", "color: #0f172a")
    expect(style).not_to include("gradient")
  end

  it "uses the neutral presentation for an empty category collection" do
    expect(helper_object.solid_or_gradient_style([])).to include("background-color: #e2e8f0", "color: #0f172a")
  end
end
