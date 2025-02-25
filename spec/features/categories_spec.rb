# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :feature do
  let(:basic) { FeatureHelper::BASIC }
  let(:category_submenu) { FeatureHelper::CATEGORY }

  let(:user) { create(:user, :random) }
  let(:category) { build(:category, :random, user:) }

  before { sign_in_as(user:) }

  feature "/categories" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: basic, sub_menu: category_submenu)
      match_center_container_content("categories")
    end
  end

  feature "/categories/index" do
    background do
      category.save
      create_list(:card_transaction, 2, :random, user:, date: Date.current, category_transactions: [ build(:category_transaction, :random, category:) ])
      navigate_to(menu: basic, sub_menu: category_submenu)
    end

    scenario "jumping to card_transactions that belong to the newly-created category" do
      find("#category_#{category.id} .jump_to_card_transactions a", match: :first).click

      match_center_container_content("card_transactions")
      params = card_transactions_search_form_params

      expect(params[:category_ids]).to eq(category.id.to_s)
    end
  end

  feature "/categories/new" do
    background do
      create(:user_card, :random, user:)
      navigate_to(menu: basic, sub_menu: category_submenu)
      click_on action_model(:newa, Category)
    end

    scenario "creating an invalid category" do
      within "turbo-frame#new_category" do
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:not_createda, Category))
    end

    scenario "creating a valid category and getting redirected to card_transaction creation with category already preselected" do
      within "turbo-frame#new_category form" do
        fill_in "category_category_name", with: "Test Category"

        find("input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:createda, Category))

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#categories_nested" do
          categories = page.all(".category_transaction_category_name").map(&:text)
          expect(categories).to include("Test Category")
        end
      end
    end
  end

  feature "/categories/edit" do
    background do
      category.save
      create(:user_card, :random, user:)
      navigate_to(menu: basic, sub_menu: category_submenu)
    end

    scenario "editing an invalid category" do
      within "turbo-frame#categories" do
        find("#edit_category_#{category.id}", match: :first).click
      end

      within "turbo-frame#category_#{category.id} form" do
        fill_in "category_category_name", with: ""
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:not_updateda, Category))
    end

    scenario "editing a valid category and getting redirected to card_transaction creation with category already preselected" do
      within "turbo-frame#categories" do
        find("#edit_category_#{category.id}", match: :first).click
      end

      within "turbo-frame#category_#{category.id} form" do
        fill_in "category_category_name", with: "Another Test Category"

        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content(notification_model(:updateda, Category))

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#categories_nested" do
          categories = page.all(".category_transaction_category_name").map(&:text)
          expect(categories).to include("Another Test Category")
        end
      end

      navigate_to(menu: basic, sub_menu: category_submenu)

      within "turbo-frame#categories turbo-frame#category_#{category.id}" do
        expect(page).to have_selector("span", text: "Another Test Category")
      end
    end
  end

  feature "/categories/destroy" do
    background do
      category.save
      navigate_to(menu: basic, sub_menu: category_submenu)
    end

    scenario "destroying a category that has no card_transactions" do
      within "turbo-frame#category_#{category.id}" do
        find("#delete_category_#{category.id}").click
      end

      expect(page).to_not have_css("turbo-frame#category_#{category.id}")

      expect(notification).to have_content(notification_model(:destroyeda, Category))
    end

    scenario "failing to destroy a category that has card_transactions" do
      create_list(:card_transaction, 2, :random, user:, date: Date.current, category_transactions: [ build(:category_transaction, :random, category:) ])

      within "turbo-frame#category_#{category.id}" do
        find("#delete_category_#{category.id}").click
      end

      expect(page).to have_css("turbo-frame#category_#{category.id}")

      expect(notification).to have_content(notification_model(:not_destroyed_because_has_transactionsa, Category))
    end
  end
end
