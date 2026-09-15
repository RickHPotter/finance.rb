# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category and entity navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let!(:user_card) { create(:user_card, :random, user:, card:) }

  before { sign_in user }

  it "renders category and entity entry screens only as canonical HTML" do
    category = create(:category, :random, user:)
    entity = create(:entity, :random, user:)

    [
      categories_path,
      new_category_path,
      category_path(category),
      edit_category_path(category),
      entities_path,
      new_entity_path,
      entity_path(entity),
      edit_entity_path(entity)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "renders in-place merge entry points for eligible desktop and mobile index rows" do
    category = create(:category, :random, user:, built_in: false)
    entity = create(:entity, :random, user:, built_in: false, entity_user: nil)
    inactive_category = create(:category, :random, user:, built_in: false, active: false)
    inactive_entity = create(:entity, :random, user:, built_in: false, active: false, entity_user: nil)
    mobile_headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" }

    [ {}, mobile_headers ].each do |request_headers|
      get categories_path, headers: request_headers
      category_document = Nokogiri::HTML.parse(response.body)
      category_trigger = category_document.at_css("#merge_category_#{category.id}")
      category_form = category_trigger.parent

      expect(category_trigger).to be_present
      expect(category_form["action"]).to eq(merge_preview_category_path(category))
      expect(category_form["data-turbo-frame"]).to eq("category_merge_preview_#{category.id}")
      expect(category_document.at_css("#category_merge_preview_#{category.id}")).to be_present
      expect(category_document.at_css("#merge_category_#{user.categories.find_by!(built_in: true).id}")).to be_nil
      expect(category_document.at_css("#merge_category_#{inactive_category.id}")).to be_nil

      get entities_path, headers: request_headers
      entity_document = Nokogiri::HTML.parse(response.body)
      entity_trigger = entity_document.at_css("#merge_entity_#{entity.id}")
      entity_form = entity_trigger.parent

      expect(entity_trigger).to be_present
      expect(entity_form["action"]).to eq(merge_preview_entity_path(entity))
      expect(entity_form["data-turbo-frame"]).to eq("entity_merge_preview_#{entity.id}")
      expect(entity_document.at_css("#entity_merge_preview_#{entity.id}")).to be_present
      expect(entity_document.at_css("#merge_entity_#{user.built_in_entity.id}")).to be_nil
      expect(entity_document.at_css("#merge_entity_#{inactive_entity.id}")).to be_nil
    end
  end

  it "keeps canonical filtered index state in merge forms without changing browser history" do
    category = create(:category, :random, user:, built_in: false)
    entity = create(:entity, :random, user:, built_in: false, entity_user: nil)
    category_return = Navigation::Categories.new(
      raw: categories_path(search_term: category.category_name, category: { status: [ "active" ] }),
      fallback: categories_path,
      current_user: user
    ).destination
    entity_return = Navigation::Entities.new(
      raw: entities_path(search_term: entity.entity_name, entity: { status: [ "active" ] }),
      fallback: entities_path,
      current_user: user
    ).destination

    { category_return => [ "category", category.id ], entity_return => [ "entity", entity.id ] }.each do |index_path, (resource, id)|
      get index_path
      form = Nokogiri::HTML.parse(response.body).at_css("#merge_#{resource}_#{id}").parent

      expect(form.at_css(%[input[name="#{resource}_merge[return_to]"]])["value"]).to eq(index_path)
      expect(form["data-turbo-action"]).to be_nil
    end
  end

  it "does not expose merge actions from category or entity show dashboards" do
    category = create(:category, :random, user:, built_in: false)
    entity = create(:entity, :random, user:, built_in: false, entity_user: nil)

    {
      category_path(category) => merge_preview_category_path(category),
      entity_path(entity) => merge_preview_entity_path(entity)
    }.each do |show_path, merge_path|
      get show_path

      document = Nokogiri::HTML.parse(response.body)
      expect(document.at_css(%[a[href^="#{merge_path}"]])).to be_nil
    end
  end

  it "canonicalizes obsolete stream-format entry URLs" do
    category = create(:category, :random, user:)
    entity = create(:entity, :random, user:)

    {
      categories_path(format: :turbo_stream) => categories_path,
      new_category_path(format: :turbo_stream) => new_category_path,
      category_path(category, format: :turbo_stream) => category_path(category),
      edit_category_path(category, format: :turbo_stream) => edit_category_path(category),
      entities_path(format: :turbo_stream) => entities_path,
      new_entity_path(format: :turbo_stream) => new_entity_path,
      entity_path(entity, format: :turbo_stream) => entity_path(entity),
      edit_entity_path(entity, format: :turbo_stream) => edit_entity_path(entity)
    }.each do |stream_path, canonical_path|
      sign_in user
      get stream_path

      expect(response).to have_http_status(:moved_permanently), "expected #{stream_path} to redirect permanently"
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "marks visible save submitters for top-level replacement while leaving hidden updates local" do
    [ new_category_path, new_entity_path ].each do |path|
      get path
      document = Nokogiri::HTML.parse(response.body)
      visible_submitter = document.at_css("form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']")
      hidden_update = document.css("form input[type='submit']").find { |input| input["value"] == "Update" }

      expect(visible_submitter).to be_present
      expect(hidden_update).to be_present
      expect(hidden_update["data-turbo-frame"]).to be_nil
      expect(hidden_update["data-turbo-action"]).to be_nil
    end
  end

  it "preserves filtered return paths through edit without rendering redundant list actions" do
    category = create(:category, :random, user:)
    entity = create(:entity, :random, user:)
    category_return = categories_path(search_term: category.category_name)
    entity_return = entities_path(search_term: entity.entity_name)

    {
      category_path(category, return_to: category_return) => [ category_return, edit_category_path(category, return_to: category_return) ],
      entity_path(entity, return_to: entity_return) => [ entity_return, edit_entity_path(entity, return_to: entity_return) ]
    }.each do |show_path, (return_path, edit_path)|
      get show_path

      document = Nokogiri::HTML.parse(response.body)
      expect(document.at_css(%[a[href="#{return_path}"]])).to be_nil
      expect(document.at_css(%[a[href="#{edit_path}"]])).to be_present
    end
  end

  it "redirects successful active creates to refreshable seeded card transaction URLs" do
    post categories_path, params: {
      category: {
        category_name: "CANONICAL CATEGORY",
        colour: "#123456",
        active: true,
        user_id: user.id
      }
    }, headers: turbo_stream_headers

    category = user.categories.find_by!(category_name: "CANONICAL CATEGORY")
    category_destination = new_card_transaction_path(
      user_card_id: user_card.id,
      card_transaction: { category_id: category.id }
    )

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(category_destination)

    get category_destination
    expect(response).to have_http_status(:success)
    expect(response.body).to include("CANONICAL CATEGORY")

    post entities_path, params: {
      entity: {
        entity_name: "CANONICAL ENTITY",
        avatar_name: "people/0.png",
        active: true,
        user_id: user.id
      }
    }, headers: turbo_stream_headers

    entity = user.entities.find_by!(entity_name: "CANONICAL ENTITY")
    entity_destination = new_card_transaction_path(
      user_card_id: user_card.id,
      card_transaction: { entity_id: entity.id }
    )

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(entity_destination)

    get entity_destination
    expect(response).to have_http_status(:success)
    expect(response.body).to include("CANONICAL ENTITY")
  end

  it "keeps validation failures bounded to the submitted form" do
    [
      [ categories_path, { category: { category_name: "", colour: "#123456", active: true, user_id: user.id } }, "new_category" ],
      [ entities_path, { entity: { entity_name: "", avatar_name: "people/0.png", active: true, user_id: user.id } }, "new_entity" ]
    ].each do |path, request_params, target|
      post path, params: request_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include(%[target="#{target}"])
      expect(response.body).not_to include(%[target="center_container"])
    end
  end

  it "redirects guarded destroys to the validated filtered index state" do
    category = create(:category, :random, user:)
    entity = create(:entity, :random, user:)
    transaction = create(:card_transaction, user:, context: user.main_context, user_card:)
    create(:category_transaction, category:, transactable: transaction)
    create(:entity_transaction, entity:, transactable: transaction)

    category_return = Navigation::Categories.new(
      raw: categories_path(search_term: category.category_name, category: { status: [ "active" ] }),
      fallback: categories_path,
      current_user: user
    ).destination
    entity_return = Navigation::Entities.new(
      raw: entities_path(search_term: entity.entity_name, entity: { status: [ "active" ] }),
      fallback: entities_path,
      current_user: user
    ).destination

    expect do
      delete category_path(category), params: { return_to: category_return }, headers: turbo_stream_headers
    end.not_to change(Category, :count)
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(category_return)

    expect do
      delete entity_path(entity), params: { return_to: entity_return }, headers: turbo_stream_headers
    end.not_to change(Entity, :count)
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(entity_return)
  end

  it "keeps built-in records protected while returning to their canonical indexes" do
    built_in_category = user.categories.find_by!(built_in: true)
    built_in_entity = user.built_in_entity

    expect do
      delete category_path(built_in_category), headers: turbo_stream_headers
    end.not_to change(Category, :count)
    expect(response).to redirect_to(categories_path)

    expect do
      delete entity_path(built_in_entity), headers: turbo_stream_headers
    end.not_to change(Entity, :count)
    expect(response).to redirect_to(entities_path)
  end
end
