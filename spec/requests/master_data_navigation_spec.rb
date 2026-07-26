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
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
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
