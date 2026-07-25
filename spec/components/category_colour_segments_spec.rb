# frozen_string_literal: true

require "rails_helper"

RSpec.describe Components::CategoryColourSegments, type: :component do
  it "renders one equal decorative segment per category using resolved backgrounds" do
    categories = [
      Category.new(id: 11, category_name: "Dark", colour: "#4b5563"),
      Category.new(id: 148, category_name: "Light", colour: "#f1f5f9")
    ]

    document = render_component(categories:)
    container = document.at_css("[data-category-colour-segments='true']")
    segments = container.css("[data-category-colour-segment='true']")

    expect(container["aria-hidden"]).to eq("true")
    expect(container["data-category-count"]).to eq("2")
    expect(segments.map { |segment| segment["data-category-id"] }).to eq(%w[11 148])
    expect(segments.map { |segment| segment["style"] }).to eq(
      [ "background-color: #4b5563;", "background-color: #f1f5f9;" ]
    )
  end

  it "does not add a decorative strip to a single-category surface" do
    category = Category.new(id: 11, category_name: "Solo", colour: "#4b5563")

    expect(render_component(categories: [ category ]).children).to be_empty
  end

  def render_component(**attributes)
    Nokogiri::HTML.fragment(described_class.new(**attributes).call)
  end
end
