# frozen_string_literal: true

require "rails_helper"

RSpec.describe Components::AllocationMutationInterface, type: :component do
  let(:user) { create(:user) }

  it "renders all six keyboard-accessible actions and the responsive dialog contract" do
    document = render_component
    dialog = document.at_css("##{described_class::MODAL_ID}")
    action_buttons = document.css("button[data-allocation-action-key]")

    expect(dialog).to be_present
    expect(dialog["role"]).to eq("dialog")
    expect(dialog["aria-modal"]).to eq("true")
    expect(dialog["aria-labelledby"]).to eq("#{described_class::MODAL_ID}_title")
    expect(action_buttons.map { |button| button["data-allocation-action-key"] }).to contain_exactly(
      "category_add",
      "category_remove",
      "category_switch",
      "entity_add",
      "entity_remove",
      "entity_switch"
    )
    expect(action_buttons).to all(satisfy { |button| button["type"] == "button" && button.key?("aria-pressed") })
  end

  it "omits protected allocation choices and exposes exact submission targets" do
    category = create(:category, user:, category_name: "CUSTOM CATEGORY")
    entity = create(:entity, user:, entity_name: "CUSTOM ENTITY")
    friend = create(:entity, user:, entity_name: "FRIEND", entity_user: create(:user, :random))
    document = render_component
    values = document.css("input[type='radio']").map { |input| input["value"] }

    expect(values).to include(category.id.to_s, entity.id.to_s)
    expect(values).not_to include(user.built_in_category("INVESTMENT").id.to_s, user.built_in_entity.id.to_s, friend.id.to_s)
    expect(document.at_css("input[data-allocation-mutation-target='ownerIds']")["name"]).to eq("allocation_mutation[owner_ids][]")
    expect(document.at_css("input[data-allocation-mutation-target='rowCount']")["name"]).to eq("allocation_mutation[selected_row_count]")
    expect(document.at_css("form")["action"]).to eq(Rails.application.routes.url_helpers.preview_allocation_mutations_path)
  end

  it "provides a BulkActionBar contract using deduplicated record IDs" do
    action = described_class.bulk_action(selection_kind: "transaction")

    expect(action).to include(
      name: "allocation",
      ids_kind: "record",
      selection_kind: "transaction"
    )
    expect(action[:data]).to include(
      action: "click->datatable#prepareBulkAction",
      modal_target: described_class::MODAL_ID,
      modal_toggle: described_class::MODAL_ID,
      allocation_mutation_launch: true
    )
  end

  private

  def render_component
    component = described_class.new(current_user: user, owner_type: "CashTransaction", return_to: "/cash_transactions")
    Nokogiri::HTML.fragment(component.render_in(ApplicationController.new.view_context))
  end
end
