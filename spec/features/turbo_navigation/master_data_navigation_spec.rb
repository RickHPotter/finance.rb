# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category and entity Turbo navigation", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "returns a saved inactive category edit to its filtered category index" do
    category = create(:category, :random, user:, active: false)
    return_to = Navigation::Categories.new(
      raw: categories_path(search_term: category.category_name, category: { status: [ "inactive" ] }),
      fallback: categories_path,
      current_user: user
    ).destination

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_category_path(category, return_to:),
      record: category,
      field: { id: "category_category_name", value: "CANONICAL CATEGORY UPDATE", attribute: :category_name }
    )
  end

  it "returns a saved inactive entity edit to its filtered entity index" do
    entity = create(:entity, :random, user:, active: false)
    return_to = Navigation::Entities.new(
      raw: entities_path(search_term: entity.entity_name, entity: { status: [ "inactive" ] }),
      fallback: entities_path,
      current_user: user
    ).destination

    exercise_edit_navigation(
      index_path: return_to,
      edit_path: edit_entity_path(entity, return_to:),
      record: entity,
      field: { id: "entity_entity_name", value: "CANONICAL ENTITY UPDATE", attribute: :entity_name }
    )
  end

  def exercise_edit_navigation(index_path:, edit_path:, record:, field:)
    visit index_path
    page.execute_script("Turbo.visit(arguments[0])", edit_path)
    expect_browser_path(edit_path)
    replace_field field[:id], with: field[:value]

    expect_workflow_finishing_submitter("form button[type='submit']")
    find("form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']", match: :first).click

    expect_browser_path(index_path)
    expect(record.reload.public_send(field[:attribute])).to eq(field[:value])
    browser_back_to(index_path)
    browser_forward_to(index_path)
    refresh_browser_at(index_path)
  end
end
