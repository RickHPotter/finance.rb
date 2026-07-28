# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Master-data navigation state" do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }

  it "retains category and entity search/status state" do
    category_state = Navigation::Categories.new(
      raw: "/categories?search_term=food&category[status][]=active",
      fallback: "/categories",
      current_user: user
    )
    entity_state = Navigation::Entities.new(
      raw: "/entities?search_term=shop&entity[status][]=inactive",
      fallback: "/entities",
      current_user: user
    )

    expect(category_state.destination).to eq("/categories?category%5Bstatus%5D%5B%5D=active&search_term=food")
    expect(entity_state.destination).to eq("/entities?entity%5Bstatus%5D%5B%5D=inactive&search_term=shop")
  end

  it "rejects foreign owned identifiers and paths outside each resource" do
    foreign_category = create(:category, :random, user: other_user)
    foreign_entity = create(:entity, :random, user: other_user)

    category_state = Navigation::Categories.new(
      raw: "/categories?category[id]=#{foreign_category.id}",
      fallback: "/categories",
      current_user: user
    )
    entity_state = Navigation::Entities.new(
      raw: "/entities?entity[id]=#{foreign_entity.id}",
      fallback: "/entities",
      current_user: user
    )
    wrong_path_state = Navigation::Categories.new(raw: "/entities", fallback: "/categories", current_user: user)

    expect(category_state.destination).to eq("/categories")
    expect(category_state.rejected_reason).to eq(:foreign_identifier)
    expect(entity_state.destination).to eq("/entities")
    expect(entity_state.rejected_reason).to eq(:foreign_identifier)
    expect(wrong_path_state.destination).to eq("/categories")
    expect(wrong_path_state.rejected_reason).to eq(:path_not_allowed)
  end
end
