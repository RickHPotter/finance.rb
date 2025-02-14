# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in_as(user:) }

  feature "/entities" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: "New", sub_menu: "Entity")
      match_center_container_content("new_entity")
    end
  end

  feature "/entities/show" do
    background do
      navigate_to(menu: "New", sub_menu: "Entity")
    end

    scenario "jumping to card_transactions that belong to the newly-created entity" do
      _entity = create(:entity, :random, user:)
      click_on "Entities"
      find("turbo-frame#center_container table tbody th:nth-child(1) span a", match: :first).click

      match_center_container_content("card_transactions")

      # TODO: search sub_menu was not yet created
      # within "turbo-frame#center_container turbo-frame#card_transactions turbo-frame#filter_options" do
      #   entity_name = find("#entity_filter", match: :first)
      #   expect(entity_name).to have_content(entity.entity_name)
      # end
    end
  end

  feature "/entities/new" do
    background do
      create(:user_card, :random, user:)
      navigate_to(menu: "New", sub_menu: "Entity")
    end

    scenario "creating an invalid entity" do
      within "turbo-frame#new_entity" do
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "creating a valid entity and getting redirected to card_transaction creation with entity already preselected" do
      within "turbo-frame#new_entity form" do
        fill_in "entity_entity_name", with: "Test Entity"

        find("input[type=submit]", match: :first).click
      end

      expect(notification).to have_content("Entity has been created.")

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#entities_nested" do
          expect(page).to have_selector("#entity_transaction_entity_id > option:nth-child(1)", text: "Test Entity")
        end
      end
    end
  end

  feature "/entities/edit" do
    background do
      create(:user_card, :random, user:)
      navigate_to(menu: "New", sub_menu: "Entity")
    end

    scenario "editing an invalid entity" do
      entity = create(:entity, :random, user:)

      within "turbo-frame#center_container" do
        click_on "Entities"
      end

      match_center_container_content("entities")

      find("#edit_entity_#{entity.id}", match: :first).click
      fill_in "entity_entity_name", with: ""
      find("form input[type=submit]", match: :first).click

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "editing a valid entity and getting redirected to card_transaction creation with entity already preselected" do
      entity = create(:entity, :random, user:)

      within "turbo-frame#center_container" do
        click_on "Entities"
        find("#edit_entity_#{entity.id}", match: :first).click

        within "turbo-frame#entity_#{entity.id} form" do
          fill_in "entity_entity_name", with: "Another Test Entity"

          find("form input[type=submit]", match: :first).click
        end
      end

      expect(notification).to have_content("Entity has been updated.")

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#entities_nested" do
          expect(page).to have_selector("#entity_transaction_entity_id > option:nth-child(1)", text: "Another Test Entity")
        end
      end

      navigate_to(menu: "New", sub_menu: "Entity")

      click_on "Entities"

      within "turbo-frame#center_container table tbody #entity_#{entity.id}" do
        expect(page).to have_selector("th:nth-child(1) span a", text: "Another Test Entity")
      end
    end
  end

  feature "/entities/destroy" do
    background do
      navigate_to(menu: "New", sub_menu: "Entity")
    end

    scenario "destroying a entity that has no card_transactions" do
      entity = create(:entity, :random, user:)

      within "turbo-frame#center_container" do
        click_on "Entities"
      end

      within "turbo-frame#entities table tbody" do
        find("a#delete_entity_#{entity.id}", match: :first).click
        expect(page).to_not have_css("tr#entity_#{entity.id}")
      end

      expect(notification).to have_content("Entity has been deleted.")
    end

    scenario "failing to destroy a entity that has card_transactions" do
      entity = create(:entity, :random, user:)
      create_list(:card_transaction, 2, :random, user:, date: Date.current, entity_transactions: [ build(:entity_transaction, :random, entity:) ])

      within "turbo-frame#center_container" do
        click_on "Entities"
      end

      within "turbo-frame#entities table tbody" do
        find("a#delete_entity_#{entity.id}", match: :first).click
        expect(page).to have_css("tr#entity_#{entity.id}")
      end

      expect(notification).to have_content("Entity with transactions cannot be deleted.")
    end
  end
end
