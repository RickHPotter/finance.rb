# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }

  before do
    create(:user_card, :random, user:, card:)
    sign_in user
  end

  describe "[ #index ]" do
    it "renders successfully" do
      get entities_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates an entity" do
      expect do
        post entities_path, params: {
          entity: {
            entity_name: "Luis",
            avatar_name: "people/0.png",
            active: true,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(Entity, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      entity = create(:entity, user:)

      patch entity_path(entity), params: {
        entity: {
          entity_name: "Updated Entity",
          avatar_name: entity.avatar_name,
          active: entity.active,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(entity.reload.entity_name).to eq("Updated Entity")
    end
  end

  describe "[ #destroy ]" do
    it "destroys an entity without transactions" do
      entity = create(:entity, user:)

      expect do
        delete entity_path(entity), headers: turbo_stream_headers
      end.to change(Entity, :count).by(-1)
    end
  end
end
