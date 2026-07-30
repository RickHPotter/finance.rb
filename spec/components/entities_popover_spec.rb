# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Entities::Popover, type: :component do
  it "marks entity badges and supporting info for row-foreground styling" do
    document = render_component(
      items: [
        {
          name: "ANA",
          avatar_name: "people/0.png",
          info_class: "entity_exchanges_info text-xs",
          info_text: "[R$ 10,00]"
        }
      ],
      mobile: false,
      target_ids: [ 42 ],
      trigger_label: "",
      variant: :cash
    )

    badge = document.at_css('[data-entity-colour="true"]')

    expect(badge).to be_present
    expect(badge.text).to include("ANA", "[R$ 10,00]")
    expect(badge.at_css('[data-entity-info-text="true"]').text).to eq("[R$ 10,00]")
  end

  it "marks a multi-entity trigger as a row-coloured badge" do
    document = render_component(
      items: [
        { name: "ANA", avatar_name: "people/0.png" },
        { name: "BRUNO", avatar_name: "people/1.png" }
      ],
      mobile: false,
      target_ids: [ 42, 43 ],
      trigger_label: "",
      variant: :cash
    )

    expect(document.at_css('button[data-entity-colour="true"]')).to be_present
  end

  it "marks multi-entity content as a theme-coloured popover surface" do
    document = render_component(
      items: [
        { name: "ANA", avatar_name: "people/0.png" },
        { name: "BRUNO", avatar_name: "people/1.png" }
      ],
      mobile: false,
      target_ids: [ 42, 43 ],
      trigger_label: "",
      variant: :cash
    )

    expect(document.at_css('[data-entity-popover-surface="true"]')).to be_present
  end

  def render_component(**attributes)
    component = described_class.new(**attributes)
    allow(component).to receive(:asset_path) { |path| "/assets/#{path}" }
    allow(component).to receive(:image_tag) { |source, options| component.img(src: source, **options) }

    Nokogiri::HTML.fragment(component.call)
  end
end
