# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in_as(user:) }

  feature "/categories" do
    scenario "center_container is swapped for correct form" do
      navigate_to(menu: "New", sub_menu: "Category")
      match_center_container_content("new_category")
    end
  end

  feature "/categories/show" do
    background do
      navigate_to(menu: "New", sub_menu: "Category")
    end

    scenario "jumping to card_transactions that belong to the newly-created category" do
      _category = create(:category, :random, user:)
      click_on "Existing Categories"
      find("turbo-frame#center_container table tbody th:nth-child(1) span a", match: :first).click

      match_center_container_content("card_transactions")

      # TODO: search sub_menu was not yet created
      # within "turbo-frame#center_container turbo-frame#card_transactions turbo-frame#filter_options" do
      #   category_name = find("#category_filter", match: :first)
      #   expect(category_name).to have_content(category.category_name)
      # end
    end
  end

  feature "/categories/new" do
    background do
      create(:user_card, :random, user:)
      navigate_to(menu: "New", sub_menu: "Category")
    end

    scenario "creating an invalid category" do
      within "turbo-frame#new_category" do
        find("form input[type=submit]", match: :first).click
      end

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "creating a valid category and getting redirected to card_transaction creation with category already preselected" do
      within "turbo-frame#new_category form" do
        fill_in "category_category_name", with: "Test Category"

        find("input[type=submit]", match: :first).click
      end

      expect(notification).to have_content("Category has been created.")

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
      create(:user_card, :random, user:)
      navigate_to(menu: "New", sub_menu: "Category")
    end

    scenario "editing an invalid category" do
      category = create(:category, :random, user:)

      within "turbo-frame#center_container" do
        click_on "Existing Categories"
      end

      match_center_container_content("categories")

      find("#edit_category_#{category.id}", match: :first).click
      fill_in "category_category_name", with: ""
      find("form input[type=submit]", match: :first).click

      expect(notification).to have_content("Something is wrong.")
    end

    scenario "editing a valid category and getting redirected to card_transaction creation with category already preselected" do
      category = create(:category, :random, user:)

      within "turbo-frame#center_container" do
        click_on "Existing Categories"
        find("#edit_category_#{category.id}", match: :first).click

        within "turbo-frame#category_#{category.id} form" do
          fill_in "category_category_name", with: "Another Test Category"

          find("form input[type=submit]", match: :first).click
        end
      end

      expect(notification).to have_content("Category has been updated.")

      match_center_container_content("new_card_transaction")

      within "turbo-frame#new_card_transaction form" do
        within "#categories_nested" do
          categories = page.all(".category_transaction_category_name").map(&:text)
          expect(categories).to include("Another Test Category")
        end
      end

      navigate_to(menu: "New", sub_menu: "Category")

      click_on "Existing Categories"

      within "turbo-frame#center_container table tbody #category_#{category.id}" do
        expect(page).to have_selector("th:nth-child(1) span a", text: "Another Test Category")
      end
    end
  end

  feature "/categories/destroy" do
    background do
      navigate_to(menu: "New", sub_menu: "Category")
    end

    scenario "destroying a category that has no card_transactions" do
      category = create(:category, :random, user:)

      within "turbo-frame#center_container" do
        click_on "Existing Categories"
      end

      within "turbo-frame#categories table tbody" do
        find("a#delete_category_#{category.id}", match: :first).click
        expect(page).to_not have_css("tr#category_#{category.id}")
      end

      expect(notification).to have_content("Category has been deleted.")
    end

    scenario "failing to destroy a category that has card_transactions" do
      category = create(:category, :random, user:)
      create_list(:card_transaction, 2, :random, user:, date: Date.current, category_transactions: [ build(:category_transaction, :random, category:) ])

      within "turbo-frame#center_container" do
        click_on "Existing Categories"
      end

      within "turbo-frame#categories table tbody" do
        find("a#delete_category_#{category.id}", match: :first).click
        expect(page).to have_css("tr#category_#{category.id}")
      end

      expect(notification).to have_content("Category with transactions cannot be deleted.")
    end
  end
end
