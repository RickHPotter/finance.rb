# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities", type: :feature do
  let(:basic) { FeatureHelper::BASIC }
  let(:entity_submenu) { FeatureHelper::ENTITY }

  let(:user) { create(:user, :random) }
  let(:entity) { build(:entity, :random, user:) }

  before { sign_in_as(user:) }

  feature "/entities" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: basic, sub_menu: entity_submenu)
      match_center_container_content("entities")
    end
  end

  feature "/entities/index" do
    background do
      entity.save
      create_list(:card_transaction, 2, :random, user:, date: Time.zone.today, entity_transactions: [ build(:entity_transaction, :random, entity:) ])
      navigate_to(menu: basic, sub_menu: entity_submenu)
    end

    scenario "jumping to card_transactions that belong to the newly-created entity" do
      find("#entity_#{entity.id} .jump_to_card_transactions a", match: :first).click

      match_center_container_content("card_transactions")
      params = card_transactions_search_form_params

      expect(params[:entity_id]).to eq(entity.id.to_s)
    end
  end

  feature "/entities/new" do
    background do
      create(:user_card, :random, user:)
      navigate_to(menu: basic, sub_menu: entity_submenu)
      click_on action_model(:newa, Entity)
    end

    scenario "creating an invalid entity" do
      within "turbo-frame#new_entity" do
        find("form button[type=submit]", match: :first).click
      end

      expect(page).to have_css("#notification-content", text: notification_model(:not_createda, Entity))
    end

    scenario "creating a valid entity and getting redirected to card_transaction creation with entity already preselected" do
      within "turbo-frame#new_entity form" do
        fill_in "entity_entity_name", with: "Test Entity"

        find("button[type=submit]", match: :first).click
      end

      expect(page).to have_css("#notification-content", text: notification_model(:createda, Entity))

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#entities_nested" do
          expect(page).to have_css(".entities_entity_name", text: "Test Entity")
        end
      end
    end
  end

  feature "/entities/edit" do
    background do
      entity.save
      create(:user_card, :random, user:)
      navigate_to(menu: basic, sub_menu: entity_submenu)
    end

    scenario "editing an invalid entity" do
      within "turbo-frame#center_container" do
        find("#edit_entity_#{entity.id}", match: :first).click
      end

      within "turbo-frame#entity_#{entity.id} form" do
        fill_in "entity_entity_name", with: ""
        find("form button[type=submit]", match: :first).click
      end

      expect(page).to have_css("#notification-content", text: notification_model(:not_updateda, Entity))
    end

    scenario "editing a valid entity and getting redirected to card_transaction creation with entity already preselected" do
      within "turbo-frame#center_container" do
        find("#edit_entity_#{entity.id}", match: :first).click
      end

      within "turbo-frame#entity_#{entity.id} form" do
        fill_in "entity_entity_name", with: "Another Test Entity"

        find("form button[type=submit]", match: :first).click
      end

      expect(page).to have_css("#notification-content", text: notification_model(:updateda, Entity))

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#entities_nested" do
          expect(page).to have_css(".entities_entity_name", text: "Another Test Entity")
        end
      end

      navigate_to(menu: basic, sub_menu: entity_submenu)

      within "turbo-frame#entities turbo-frame#entity_#{entity.id}" do
        expect(page).to have_css("span", text: "Another Test Entity")
      end
    end
  end

  feature "/entities/destroy" do
    background do
      entity.save
      navigate_to(menu: basic, sub_menu: entity_submenu)
    end

    scenario "destroying a entity that has no card_transactions" do
      within "turbo-frame#entity_#{entity.id}" do
        find("#delete_entity_#{entity.id}").click
        accept_alert
      end

      expect(page).to_not have_css("turbo-frame#entity_#{entity.id}")

      expect(page).to have_css("#notification-content", text: notification_model(:destroyeda, Entity))
    end

    scenario "failing to destroy a entity that has card_transactions" do
      create_list(:card_transaction, 2, :random, user:, date: Time.zone.today, entity_transactions: [ build(:entity_transaction, :random, entity:) ])

      within "turbo-frame#entity_#{entity.id}" do
        find("#delete_entity_#{entity.id}").click
        accept_alert
      end

      expect(page).to have_css("turbo-frame#entity_#{entity.id}")

      expect(page).to have_css("#notification-content", text: notification_model(:not_destroyed_because_has_transactionsa, Entity))
    end
  end
end
